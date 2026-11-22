import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from './config.js';
export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
export const thresholds = [0,60,120,200];
export const level = xp => thresholds.reduce((n,t) => xp >= t ? n+1 : n,0);
export const monthKey = () => new Intl.DateTimeFormat('sv-SE',{timeZone:'Europe/Berlin',year:'numeric',month:'2-digit'}).format(new Date());
export const childEmail = username => `${username.toLowerCase()}@children.familyquest.invalid`;
export async function loadFamily() {
  const { data: session } = await supabase.auth.getUser();
  if (!session.user) return null;
  const { data: self, error: meError } = await supabase.from('members').select('*').eq('user_id',session.user.id).maybeSingle();
  if (meError) throw meError;
  if (!self) return { needsFamily: true };
  const { error: syncError } = await supabase.rpc('fq_sync');
  if (syncError) throw syncError;
  const [family, members, tasks, rewards, archive] = await Promise.all([
    supabase.from('families').select('id,name').eq('id',self.family_id).single(),
    supabase.from('members').select('*').eq('family_id',self.family_id).order('created_at'),
    supabase.from('tasks').select('*').eq('family_id',self.family_id).order('created_at',{ascending:false}),
    supabase.from('rewards').select('*').eq('family_id',self.family_id).order('created_at',{ascending:false}),
    supabase.from('monthly_archive').select('*').eq('family_id',self.family_id).order('month',{ascending:false}).limit(30)
  ]);
  for (const result of [family,members,tasks,rewards,archive]) if (result.error) throw result.error;
  const mapMember = m => ({...m,careerXp:m.career_xp});
  return { family:family.data, self:mapMember(members.data.find(m=>m.user_id===session.user.id)),
    members:members.data.map(mapMember),tasks:tasks.data.map(t=>({...t,memberId:t.member_id})),
    rewards:rewards.data,archive:archive.data,month:monthKey() };
}
export async function action(action,id=null,data={}) {
  const {error} = await supabase.rpc('fq_action',{p_action:action,p_id:id,p_data:data});
  if (error) throw error;
}
export async function createFamily(familyName,name) {
  const {error}=await supabase.rpc('fq_create_family',{p_family_name:familyName,p_name:name});
  if (error) throw error;
}
export async function joinParent(code,name) {
  const {error}=await supabase.rpc('fq_join_parent',{p_code:code,p_name:name});
  if (error) throw error;
}
export async function parentInvite() {
  const {data,error}=await supabase.rpc('fq_parent_invite');
  if (error) throw error;
  return data;
}
export async function createChild(name,username,password) {
  const {data,error}=await supabase.functions.invoke('create-child',{body:{name,username,password}});
  if (error) throw error;
  if (data?.error) throw Error(data.error);
  return data;
}
