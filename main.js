import { supabase, loadFamily, action, createFamily, joinParent, parentInvite, createChild, level, thresholds, childEmail } from './storage.js';
const $ = id => document.getElementById(id);
const esc = s => String(s ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let state = null;
const actor = () => state?.self;
const parent = () => actor()?.role === 'parent';
const member = id => state?.members.find(m => m.id === id);
const opts = () => state.members.map(m => `<option value="${esc(m.id)}">${esc(m.name)} (${m.role==='parent'?'Eltern':'Kind'})</option>`).join('');
const message = text => { $('message').textContent = text || ''; };
const busy = async fn => { message(''); try { await fn(); } catch (e) { console.error(e); message(e.message || 'Fehler beim Speichern'); } };
const canTask = () => parent() || level(actor().xp) >= 3;
const canReward = () => parent() || level(actor().xp) >= 2;

async function refresh() {
  state = await loadFamily();
  $('authPanel').hidden = !!(await supabase.auth.getUser()).data.user;
  $('setupPanel').hidden = !state?.needsFamily;
  $('appPanel').hidden = !state || !!state.needsFamily;
  if (state && !state.needsFamily) render();
}
function taskHtml(t) {
  const m=member(t.memberId);
  const status={open:'Offen',pending:'Wartet auf Bestätigung',proposed:'Vorschlag wartet auf Freigabe',done:'Erledigt'}[t.status];
  return `<div class="task"><div><strong>${esc(t.title)}</strong><small>${esc(m?.name || 'Unbekannt')} · ${t.type==='bonus'?'Bonus':'Regulär'} · ${t.repeat==='daily'?'Täglich':t.repeat==='weekly'?'Wöchentlich':'Einmalig'} · ${m?.role==='child'?t.xp+' XP · ':''}${t.coins} Münzen</small><span class="pill">${status}</span></div><div class="actions">${t.status==='open'&&(parent()||t.memberId===actor().id)?`<button data-action="complete" data-id="${t.id}">Erledigt melden</button>`:''}${parent()&&t.status==='pending'?`<button data-action="approve" data-id="${t.id}">Bestätigen</button><button class="secondary" data-action="reject" data-id="${t.id}">Ablehnen</button>`:''}${parent()&&t.status==='proposed'?`<button data-action="acceptProposal" data-id="${t.id}">Vorschlag freigeben</button><button class="secondary" data-action="rejectProposal" data-id="${t.id}">Ablehnen</button>`:''}${parent()?`<button class="danger" data-action="deleteTask" data-id="${t.id}">Löschen</button>`:''}</div></div>`;
}
function render() {
  const a=actor();
  $('familyTitle').textContent = state.family.name + ' · ' + a.name;
  $('access').textContent = parent()?'Elternkonto · volle Verwaltungsrechte':`Kinderkonto · Level ${level(a.xp)} · ${canTask()?'Aufgaben vorschlagen':canReward()?'Belohnungen vorschlagen':'Eigene Aufgaben erledigen'}`;
  $('month').textContent = state.month;
  $('taskCreator').hidden = !canTask();
  $('rewardCreator').hidden = !canReward();
  $('memberCreator').hidden = !parent();
  $('taskSubmit').textContent = parent()?'Aufgabe hinzufügen':'Aufgabenvorschlag senden';
  $('rewardSubmit').textContent = parent()?'Belohnung hinzufügen':'Belohnung vorschlagen';
  $('taskMember').innerHTML = opts();
  $('taskMember').value = state.members.some(m=>m.id===$('taskMember').dataset.selected)?$('taskMember').dataset.selected:a.id;
  $('taskPoints').hidden = !parent();
  $('taskType').disabled = !parent(); $('taskRepeat').disabled = !parent();
  const open=state.tasks.filter(t=>t.status!=='done');
  $('stats').innerHTML = `<div class="card"><div class="muted">Familienmitglieder</div><div class="stat">${state.members.length}</div></div><div class="card"><div class="muted">Offene Aufgaben</div><div class="stat">${open.length}</div></div><div class="card"><div class="muted">Monats-XP</div><div class="stat">${state.members.filter(m=>m.role==='child').reduce((s,m)=>s+m.xp,0)}</div></div><div class="card"><div class="muted">Münzguthaben</div><div class="stat">${state.members.reduce((s,m)=>s+m.coins,0)}</div></div>`;
  $('dashboardTasks').innerHTML=open.length?open.slice(0,6).map(taskHtml).join(''):'<p class="empty">Alles erledigt!</p>';
  $('taskList').innerHTML=state.tasks.map(taskHtml).join('')||'<p class="empty">Noch keine Aufgaben.</p>';
  $('rewardMember').innerHTML=opts();
  $('rewardMember').value=parent()&&state.members.some(m=>m.id===$('rewardMember').dataset.selected)?$('rewardMember').dataset.selected:a.id;
  $('rewardMember').disabled=!parent();
  const target=member($('rewardMember').value);
  $('rewardList').innerHTML=state.rewards.map(r=>`<div class="task"><div><strong>${esc(r.title)}</strong><small>${r.cost} Münzen · Guthaben: ${target?.coins||0}${r.status==='proposed'?' · Wartet auf Elternfreigabe':''}</small></div><div class="actions">${r.status==='proposed'?(parent()?`<button data-action="approveReward" data-id="${r.id}">Freigeben</button><button class="secondary" data-action="rejectReward" data-id="${r.id}">Ablehnen</button>`:''):`<button data-action="redeem" data-id="${r.id}" ${target?.coins>=r.cost?'':'disabled'}>Einlösen</button>`}${parent()?`<button class="danger" data-action="deleteReward" data-id="${r.id}">Löschen</button>`:''}</div></div>`).join('')||'<p class="empty">Noch keine Belohnungen.</p>';
  $('members').innerHTML=state.members.map(m=>`<div class="card"><h3>${esc(m.name)}</h3><span class="pill">${m.role==='parent'?'Elternteil':'Kind'}</span><p>${m.role==='child'?'⭐ '+m.xp+' Monats-XP · ':''}🪙 ${m.coins} Münzen</p><small class="muted">${m.role==='child'?'Level '+level(m.xp)+' · Karriere-XP '+m.careerXp:'Volle Verwaltungsrechte · kein XP-System'}</small></div>`).join('');
  $('levelInfo').innerHTML=thresholds.map((xp,i)=>`<div class="level"><strong>Level ${i+1} · ${xp} XP</strong><span>${['Aufgaben erledigen','Eigene Belohnungen vorschlagen (Elternfreigabe)','Wochenendaufgaben für alle vorschlagen (Elternfreigabe)','Familien-Challenges (geplant)'][i]}</span></div>`).join('');
  $('archive').innerHTML=state.archive.map(a=>`<p>${esc(a.month)} · ${esc(member(a.member_id)?.name || 'Mitglied')} · ${a.xp} XP</p>`).join('')||'<p class="muted">Noch kein Monatsabschluss.</p>';
}
$('authMode').addEventListener('change',()=>{
  const reg=$('authMode').value==='register';
  $('loginType').hidden=reg;
  if(reg)$('loginType').value='email';
  $('authIdentity').placeholder=reg||$('loginType').value==='email'?'E-Mail-Adresse':'Benutzername';
  $('authPassword').autocomplete=reg?'new-password':'current-password';
});
$('loginType').addEventListener('change',()=>{$('authIdentity').placeholder=$('loginType').value==='email'?'E-Mail-Adresse':'Benutzername';});
$('authForm').addEventListener('submit',e=>{e.preventDefault();busy(async()=>{
  const reg=$('authMode').value==='register';
  const identity=$('authIdentity').value.trim();
  const email=reg||$('loginType').value==='email'?identity:childEmail(identity);
  const password=$('authPassword').value;
  const result=reg?await supabase.auth.signUp({email,password}):await supabase.auth.signInWithPassword({email,password});
  if(result.error)throw result.error;
  if(reg&&!result.data.session)message('Bitte bestätige die Registrierung über den Link in deiner E-Mail. Danach anmelden.');
  else await refresh();
});});
$('createFamilyForm').addEventListener('submit',e=>{e.preventDefault();busy(async()=>{const f=new FormData(e.target);await createFamily(f.get('family'),f.get('name'));await refresh();});});
$('joinFamilyForm').addEventListener('submit',e=>{e.preventDefault();busy(async()=>{const f=new FormData(e.target);await joinParent(f.get('code'),f.get('name'));await refresh();});});
$('logout').addEventListener('click',()=>busy(async()=>{await supabase.auth.signOut();state=null;await refresh();}));
$('refresh').addEventListener('click',()=>busy(refresh));
$('inviteParent').addEventListener('click',()=>busy(async()=>{$('inviteOutput').textContent='Einladungscode (nur persönlich weitergeben): '+await parentInvite();}));
$('memberForm').addEventListener('submit',e=>{e.preventDefault();busy(async()=>{const f=new FormData(e.target);await createChild(f.get('name'),f.get('username'),f.get('password'));e.target.reset();await refresh();message('Kinderkonto erstellt. Zugangsdaten sicher aufbewahren.');});});
$('taskForm').addEventListener('submit',e=>{e.preventDefault();busy(async()=>{const f=new FormData(e.target);await action('create_task',null,{title:f.get('title'),memberId:f.get('memberId'),type:f.get('type'),repeat:f.get('repeat'),xp:Number(f.get('xp')),coins:Number(f.get('coins'))});e.target.reset();await refresh();});});
$('rewardForm').addEventListener('submit',e=>{e.preventDefault();busy(async()=>{const f=new FormData(e.target);await action('create_reward',null,{title:f.get('title'),cost:Number(f.get('cost'))});e.target.reset();await refresh();});});
$('taskMember').addEventListener('change',e=>{e.target.dataset.selected=e.target.value;});
$('rewardMember').addEventListener('change',e=>{e.target.dataset.selected=e.target.value;render();});
document.querySelectorAll('nav button').forEach(b=>b.addEventListener('click',()=>{document.querySelectorAll('nav button,section').forEach(x=>x.classList.remove('active'));b.classList.add('active');$(b.dataset.tab).classList.add('active');}));
document.addEventListener('click',e=>{const b=e.target.closest('[data-action]');if(!b)return;const {action:act,id}=b.dataset;
  if(['deleteTask','deleteReward','redeem'].includes(act)&&!confirm(act==='redeem'?'Belohnung für Münzen einlösen?':'Wirklich löschen?'))return;
  busy(async()=>{await action(act,id,act==='redeem'?{memberId:$('rewardMember').value}:{});await refresh();});
});
await busy(refresh);
