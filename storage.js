// Austauschbarer lokaler Adapter. Später: Supabase mit Auth, family_id und RLS.
const KEY='familyquest-v1';
export const demo={members:[{id:'p1',name:'Elternteil 1',role:'parent',xp:0,coins:0},{id:'p2',name:'Elternteil 2',role:'parent',xp:0,coins:0},{id:'c1',name:'Kind 1',role:'child',xp:0,coins:0},{id:'c2',name:'Kind 2',role:'child',xp:0,coins:0},{id:'c3',name:'Kind 3',role:'child',xp:0,coins:0}],tasks:[{id:'t1',title:'Spülmaschine ausräumen',memberId:'c1',xp:10,coins:5,status:'open',repeat:'daily',type:'regular'},{id:'t2',title:'Müll rausbringen',memberId:'c2',xp:15,coins:10,status:'open',repeat:'weekly',type:'bonus'},{id:'t3',title:'Einkaufen',memberId:'p1',xp:20,coins:5,status:'open',repeat:'weekly',type:'regular'},{id:'t4',title:'Wäsche waschen',memberId:'p2',xp:15,coins:5,status:'open',repeat:'weekly',type:'regular'}],rewards:[{id:'r1',title:'Filmabend aussuchen',cost:30},{id:'r2',title:'Wunschaktivität',cost:60}],history:[]};
export const monthKey=(date=new Date())=>`${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}`;
export const thresholds=[0,100,250,450,700];
export const level=xp=>thresholds.reduce((n,t)=>xp>=t?n+1:n,0);
export function normalize(raw){const s=raw&&Array.isArray(raw.members)&&Array.isArray(raw.tasks)?raw:structuredClone(demo);s.history??=[];s.rewards??=[];s.month??=monthKey();s.archive??=[];for(const m of s.members){m.xp=Number(m.xp)||0;m.coins=Number(m.coins)||0;m.careerXp??=m.xp}return s}
export function rollover(s,now=monthKey()){if(s.month===now)return false;s.archive.push({month:s.month,members:s.members.map(m=>({id:m.id,name:m.name,xp:m.xp,level:level(m.xp)}))});for(const m of s.members)m.xp=0;s.month=now;return true}
export const localStore={async load(){let raw;try{raw=JSON.parse(localStorage.getItem(KEY))}catch{}const s=normalize(raw);if(rollover(s))await this.save(s);return s},async save(data){localStorage.setItem(KEY,JSON.stringify(data))}};
// Später: gleicher Vertrag load()/save() oder granularere Methoden im Supabase-Adapter.
// Berechtigungen müssen dann SERVERSEITIG über RLS und Auth durchgesetzt werden.
