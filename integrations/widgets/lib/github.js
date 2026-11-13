.pragma library
function username(value) { const user=String(value || '').trim(); return /^[a-z\d](?:[a-z\d-]{0,37}[a-z\d])?$/i.test(user) ? user : ''; }
function calendar(payload,year,today) {
 if(!payload || !Array.isArray(payload.contributions))throw new Error('Invalid contribution response');
 const byDate={};
 for(const day of payload.contributions){if(day && /^\d{4}-\d{2}-\d{2}$/.test(day.date) && Number.isFinite(day.count) && day.count>=0)byDate[day.date]={date:day.date,count:Math.floor(day.count),level:Math.max(0,Math.min(4,Number(day.level)||0))};}
 const now=new Date();
 const cutoff=today || now.getFullYear()+"-"+String(now.getMonth()+1).padStart(2,"0")+"-"+String(now.getDate()).padStart(2,"0");
 const start=new Date(Date.UTC(year,0,1));const end=new Date(Date.UTC(year+1,0,1));
 const cells=[];let total=0;
 for(let i=0;i<start.getUTCDay();i++)cells.push({date:'',count:0,level:0});
 for(let time=start.getTime();time<end.getTime();time+=86400000){const date=new Date(time).toISOString().slice(0,10);const day=byDate[date]||{date,count:0,level:0};cells.push(date<=cutoff?day:{date:"",count:0,level:0});if(date<=cutoff)total+=day.count;}
 while(cells.length && !cells[cells.length-1].date)cells.pop();
 while(cells.length%7)cells.push({date:'',count:0,level:0});
 return {cells,total,weeks:cells.length/7};
}
function windowed(calendar,minWeeks,maxWeeks,width,height){
 const minimum=Math.max(4,Math.min(53,Math.floor(Number(minWeeks)||12)));
 const maximum=Math.max(minimum,Math.min(53,Math.floor(Number(maxWeeks)||53)));
 const desired=Math.max(minimum,Math.min(maximum,Math.floor((Math.max(1,width)+3)/(Math.max(8,((Number(height)||77)-18)/7)+3))));
 const cells=calendar.cells.slice(-desired*7);
 const missing=Math.max(0,minimum*7-cells.length);
 for(let i=0;i<missing;i++)cells.unshift({date:'',count:0,level:0});
 return {cells,total:calendar.total,weeks:Math.max(minimum,cells.length/7)};
}
