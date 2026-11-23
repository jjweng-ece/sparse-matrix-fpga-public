'use strict';
const D=window.PROJECT_DATA,$=s=>document.querySelector(s),clone=x=>JSON.parse(JSON.stringify(x));
const A=D.golden.a,B=D.golden.b,frames=[];let csrTimer=null,rtlTimer=null,activeTab='csr';
let values=[],cols=[],ptr=[0],C=Array.from({length:4},()=>Array(4).fill(null)),macs=0;
function snapshot(extra){frames.push({...extra,values:[...values],cols:[...cols],ptr:[...ptr],c:clone(C),macs});}
snapshot({phase:'encoding',kind:'start',title:'先把 A 的非零資訊存下來',detail:'CSR = Compressed Sparse Row，壓縮稀疏列格式。先逐列看 A，再記錄值、欄號與每列的起終點。'});
for(let r=0;r<4;r++){
  for(let k=0;k<4;k++){
    const a=A[r][k];if(a!==0){values.push(a);cols.push(k)}
    snapshot({phase:'encoding',kind:a===0?'skip':'store',row:r,k,pos:a===0?-1:values.length-1,title:a===0?`A[${r},${k}] = 0，略過儲存`:`A[${r},${k}] = ${a}，值與欄號一起存`,detail:a===0?'這裡省的是 A 的儲存與後續排程；不是丟掉介面上的有效交易。':`values 加入 ${a}，col_idx 加入 ${k}。之後用這個欄號 k 讀取 B[k,c]。`});
  }
  ptr.push(values.length);
  snapshot({phase:'encoding',kind:'pointer',row:r,title:`第 ${r} 列結束：row_ptr[${r+1}] = ${values.length}`,detail:ptr[r]===ptr[r+1]?`起點與終點都為 ${ptr[r]}，代表空列。後面不發乘法，也要寫出四個零。`:`第 ${r} 列的非零項在位置 [${ptr[r]}, ${ptr[r+1]})，終點不包含。`});
}
const multiplyStart=frames.length;
for(let r=0;r<4;r++)for(let c=0;c<4;c++){
  let acc=0;
  snapshot({phase:'multiply',kind:'seed',row:r,col:c,acc,title:`準備 C[${r},${c}]，累加器清為 0`,detail:`讀取 row_ptr[${r}]=${ptr[r]} 與 row_ptr[${r+1}]=${ptr[r+1]}。`});
  for(let pos=ptr[r];pos<ptr[r+1];pos++){
    const k=cols[pos],a=values[pos],b=B[k][c],product=a*b;acc=(acc+product)|0;macs++;
    snapshot({phase:'multiply',kind:'mac',row:r,col:c,k,pos,a,b,product,acc,title:`位置 ${pos}：${a} × ${b}，acc = ${acc}`,detail:`col_idx[${pos}] = ${k}，所以取 B[${k},${c}]。${b===0?'B 為零也照常安排：本引擎只利用 A 的稀疏性。':'乘積加入 signed 32-bit 累加器。'}`});
  }
  C[r][c]=acc;
  snapshot({phase:'multiply',kind:'write',row:r,col:c,acc,title:`寫回 C[${r},${c}] = ${acc}`,detail:ptr[r]===ptr[r+1]?'空列沒有乘法交易，仍須完成零結果寫回。':'教學中合併呈現退休與寫回；真正 RTL 還有 DRAIN 等待最後一筆乘積。'});
}
snapshot({phase:'finished',kind:'finish',title:'16 個輸出全部完成，與 Golden 一致',detail:'CSR 共安排 16 筆 MAC；Dense 為 64 筆。實際 RTL busy cycles 是 90 對 178，另有索引、檢查、等待與寫回成本。'});
if(JSON.stringify(C)!==JSON.stringify(D.golden.c))throw Error('Teaching arithmetic differs from saved Golden');
if(JSON.stringify(values)!==JSON.stringify(D.golden.values)||JSON.stringify(cols)!==JSON.stringify(D.golden.col_idx)||JSON.stringify(ptr)!==JSON.stringify(D.golden.row_ptr))throw Error('CSR encoding differs from saved Golden');
function cellMatrix(target,matrix,highlight,type){
  $(target).innerHTML=matrix.map((row,r)=>row.map((v,c)=>`<div class="cell${v===0?' zero':''}${highlight&&highlight[0]===r&&highlight[1]===c?' '+type:''}" data-row="${r}" data-col="${c}" aria-label="row ${r}, column ${c}, value ${v===null?'not written':v}">${v===null?'·':v}</div>`).join('')).join('');
}
function array(target,list,highlight){$(target).innerHTML=list.length?list.map((v,i)=>`<div class="entry${i===highlight?' active':''}"><small>[${i}]</small>${v}</div>`).join(''):'<span class="empty">尚未填入</span>';}
function render(){
  const i=+$('#step').value,f=frames[i];$('#stepText').textContent=`${i+1} / ${frames.length}`;
  $('#phase').textContent=f.phase==='encoding'?'Dense A → CSR 編碼':f.phase==='multiply'?'CSR A × Dense B → C':'完成 / Complete';
  $('#headline').textContent=f.title;$('#explain').textContent=f.detail;
  cellMatrix('#matrixA',A,f.k===undefined?null:[f.row,f.k],'active');
  cellMatrix('#matrixB',B,f.kind==='mac'?[f.k,f.col]:null,'active');
  cellMatrix('#matrixC',f.c,f.col===undefined?null:[f.row,f.col],'target');
  array('#values',f.values,f.pos);array('#cols',f.cols,f.pos);array('#ptr',f.ptr,f.kind==='pointer'?f.row+1:f.row);
  $('#macCount').textContent=`${f.macs} / 16`;$('#operation').textContent=f.kind==='mac'?`${f.a} × ${f.b} = ${f.product}`:'—';$('#accText').textContent=f.acc===undefined?'等待排程':`acc = ${f.acc}`;
  $('#prev').disabled=i===0;$('#next').disabled=i===frames.length-1;
}
function pause(){clearInterval(csrTimer);csrTimer=null;$('#play').textContent='播放';}
function jump(i){pause();$('#step').value=i;render();}
$('#step').max=frames.length-1;$('#step').oninput=()=>{pause();render()};
$('#prev').onclick=()=>jump(Math.max(0,+$('#step').value-1));$('#next').onclick=()=>jump(Math.min(frames.length-1,+$('#step').value+1));
$('#restart').onclick=()=>jump(0);$('#encodeStart').onclick=()=>jump(0);$('#multiplyStart').onclick=()=>jump(multiplyStart);$('#finish').onclick=()=>jump(frames.length-1);
$('#play').onclick=()=>{if(csrTimer){pause();return}if(+$('#step').value===frames.length-1)jump(0);$('#play').textContent='暫停';csrTimer=setInterval(()=>{const next=+$('#step').value+1;if(next>=frames.length){pause();return}$('#step').value=next;render()},+$('#speed').value)};
$('#speed').onchange=()=>{const was=!!csrTimer;pause();if(was)$('#play').click()};
function rtl(){
  const r=D.mac[+$('#rtlStep').value];$('#rtlTime').textContent=r.time_ps/1000+' ns';
  $('#signals').innerHTML=['rst_n','load_acc','in_valid','a','b','product_q','product_valid','out_valid','acc'].map(k=>`<article class="signal"><span>${k}</span><strong data-signal="${k}">${r[k]}</strong></article>`).join('');
  let title,detail;
  if(!r.rst_n){title='同步 Reset：狀態清零';detail='在時脈上升緣清除 product、acc 與 valid。'}
  else if(r.load_acc){title='load_acc 優先：載入初值並 flush';detail='尚未退休的乘積不能跨越這次載入，valid 一起清除。'}
  else if(r.acc===-2147483648){title='32-bit overflow：回繞到負數';detail='0x7fffffff + 1 → 0x80000000。這是規格定義的 modulo 2³²。'}
  else if(r.time_ps===51000){title='這拍收下 3 × 5，product_q = 15';detail='acc 仍是 0。非阻塞指定讀取舊值，這筆乘積下一拍才退休。'}
  else if(r.time_ps===71000){title='上一筆累加成 15，同時收下零乘積';detail='0 × −7 仍是有效交易，product_q = 0，不能因此丟掉 valid。'}
  else if(r.time_ps===91000){title='零乘積退休：acc 不變，out_valid = 1';detail='數值沒有變，不代表沒有交易。同時已收下 −2 × 4 = −8。'}
  else{title=r.out_valid?'上一筆乘積退休／Retire':'保持或捕捉／Hold or capture';detail='16-bit product_q 與 32-bit acc 是不同暫存器；valid 必須與資料對齊。'}
  $('#rtlTitle').textContent=title;$('#rtlExplain').textContent=detail;
}
function stopRtl(){clearInterval(rtlTimer);rtlTimer=null;$('#rtlPlay').textContent='播放逐拍'}
$('#rtlStep').max=D.mac.length-1;$('#rtlStep').oninput=()=>{stopRtl();rtl()};
$('#rtlPrev').onclick=()=>{stopRtl();$('#rtlStep').value=Math.max(0,+$('#rtlStep').value-1);rtl()};
$('#rtlNext').onclick=()=>{stopRtl();$('#rtlStep').value=Math.min(D.mac.length-1,+$('#rtlStep').value+1);rtl()};
$('#rtlPlay').onclick=()=>{if(rtlTimer){stopRtl();return}if(+$('#rtlStep').value===D.mac.length-1)$('#rtlStep').value=0;$('#rtlPlay').textContent='暫停';rtlTimer=setInterval(()=>{let next=+$('#rtlStep').value+1;if(next>=D.mac.length){stopRtl();return}$('#rtlStep').value=next;rtl()},1100)};
function tab(name){pause();stopRtl();activeTab=name;for(const el of document.querySelectorAll('.tab'))el.hidden=el.id!==name;for(const button of document.querySelectorAll('[data-tab]'))button.setAttribute('aria-selected',String(button.dataset.tab===name))}
document.querySelectorAll('[data-tab]').forEach(button=>button.onclick=()=>tab(button.dataset.tab));
$('#boardRows').innerHTML=D.board.map(row=>'<tr>'+['profile','dense_cycles','csr_cycles','dense_macs','csr_macs'].map(key=>`<td>${row[key]}</td>`).join('')+'</tr>').join('');
window.demo={frames,multiplyStart,jump,tab,rtl,index:()=>+$('#step').value};render();rtl();
