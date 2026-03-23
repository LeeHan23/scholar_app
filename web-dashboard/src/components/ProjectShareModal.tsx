"use client";

import { useState, useEffect } from 'react';
import { X, UserPlus, Trash2, Crown, PenLine, Eye } from 'lucide-react';
import { supabase } from '../lib/supabaseClient';

interface ProjectMember {
  id: number;
  project_id: number;
  user_id: string | null;
  role: 'owner' | 'editor' | 'viewer';
  invited_email: string | null;
  accepted: boolean;
  created_at: string;
}

interface Props {
  project: { id: number; name: string };
  currentUserId: string;
  currentUserEmail: string;
  supabaseUrl: string;
  accessToken: string;
  onClose: () => void;
}

const ROLE_CONFIG = {
  owner:  { label: 'Owner',  color: '#a855f7', bg: 'rgba(168,85,247,0.15)', Icon: Crown },
  editor: { label: 'Editor', color: '#3b82f6', bg: 'rgba(59,130,246,0.15)', Icon: PenLine },
  viewer: { label: 'Viewer', color: '#94a3b8', bg: 'rgba(148,163,184,0.15)', Icon: Eye },
};

export default function ProjectShareModal({ project, currentUserId, currentUserEmail, supabaseUrl, accessToken, onClose }: Props) {
  const [members, setMembers] = useState<ProjectMember[]>([]);
  const [loading, setLoading] = useState(true);
  const [inviteEmail, setInviteEmail] = useState('');
  const [inviteRole, setInviteRole] = useState<'editor' | 'viewer'>('viewer');
  const [isInviting, setIsInviting] = useState(false);
  const [inviteMsg, setInviteMsg] = useState<{ text: string; ok: boolean } | null>(null);
  const [updatingId, setUpdatingId] = useState<number | null>(null);

  useEffect(() => {
    fetchMembers();
  }, []);

  const fetchMembers = async () => {
    setLoading(true);
    const { data } = await supabase
      .from('project_members')
      .select('*')
      .eq('project_id', project.id)
      .order('created_at', { ascending: true });
    setMembers(data ?? []);
    setLoading(false);
  };

  const sendInvite = async () => {
    if (!inviteEmail.trim()) return;
    setIsInviting(true);
    setInviteMsg(null);
    try {
      const res = await fetch(`${supabaseUrl}/functions/v1/invite-member`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ projectId: project.id, invitedEmail: inviteEmail.trim(), role: inviteRole }),
      });
      const json = await res.json();
      if (!res.ok) {
        setInviteMsg({ text: json.error ?? 'Invite failed', ok: false });
      } else {
        setInviteEmail('');
        setInviteMsg({ text: `Invitation sent to ${inviteEmail.trim()}`, ok: true });
        await fetchMembers();
      }
    } catch {
      setInviteMsg({ text: 'Network error', ok: false });
    }
    setIsInviting(false);
  };

  const updateRole = async (member: ProjectMember, role: 'editor' | 'viewer') => {
    if (!member.id) return;
    setUpdatingId(member.id);
    await supabase.from('project_members').update({ role }).eq('id', member.id);
    setMembers(prev => prev.map(m => m.id === member.id ? { ...m, role } : m));
    setUpdatingId(null);
  };

  const removeMember = async (member: ProjectMember) => {
    if (!member.id) return;
    if (!confirm(`Remove ${member.invited_email} from this project?`)) return;
    setUpdatingId(member.id);
    await supabase.from('project_members').delete().eq('id', member.id);
    setMembers(prev => prev.filter(m => m.id !== member.id));
    setUpdatingId(null);
  };

  const isOwner = members.some(m => m.user_id === currentUserId && m.role === 'owner')
    || !members.some(m => m.role === 'owner'); // treat project creator as owner if no member row yet

  return (
    <div className="share-modal-overlay" onClick={onClose}>
      <div className="share-modal" onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div className="share-modal-header">
          <div>
            <h2 style={{ margin: 0, fontSize: '1.1rem', color: 'var(--text-primary)' }}>{project.name}</h2>
            <p style={{ margin: '2px 0 0', fontSize: '0.8rem', color: 'var(--text-secondary)' }}>Manage group members</p>
          </div>
          <button className="share-modal-close" onClick={onClose}><X size={18} /></button>
        </div>

        {/* Invite form (owner only) */}
        {isOwner && (
          <div className="invite-form">
            <h3 className="share-section-title"><UserPlus size={15} /> Invite Member</h3>
            <div className="invite-row">
              <input
                type="email"
                className="invite-input"
                placeholder="Email address"
                value={inviteEmail}
                onChange={e => setInviteEmail(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && sendInvite()}
              />
              <select
                className="invite-role-select"
                value={inviteRole}
                onChange={e => setInviteRole(e.target.value as 'editor' | 'viewer')}
              >
                <option value="viewer">Viewer</option>
                <option value="editor">Editor</option>
              </select>
              <button
                className="btn-invite"
                onClick={sendInvite}
                disabled={!inviteEmail.trim() || isInviting}
              >
                {isInviting ? '…' : 'Invite'}
              </button>
            </div>
            {inviteMsg && (
              <p className={`invite-feedback ${inviteMsg.ok ? 'invite-feedback-ok' : 'invite-feedback-err'}`}>
                {inviteMsg.text}
              </p>
            )}
          </div>
        )}

        {/* Members list */}
        <div className="members-list">
          <h3 className="share-section-title" style={{ padding: '0 20px' }}>
            Members {!loading && `(${members.length})`}
          </h3>
          {loading ? (
            <p style={{ padding: '16px 20px', color: 'var(--text-secondary)', fontSize: '0.875rem' }}>Loading…</p>
          ) : members.length === 0 ? (
            <p style={{ padding: '16px 20px', color: 'var(--text-secondary)', fontSize: '0.875rem' }}>No members yet. Invite someone above.</p>
          ) : (
            members.map(member => {
              const role = ROLE_CONFIG[member.role];
              const isSelf = member.user_id === currentUserId || member.invited_email === currentUserEmail;
              const canManage = isOwner && !isSelf && member.role !== 'owner';
              return (
                <div key={member.id} className={`member-row ${updatingId === member.id ? 'member-row-loading' : ''}`}>
                  <div className="member-avatar">
                    {(member.invited_email ?? '?')[0].toUpperCase()}
                  </div>
                  <div className="member-info">
                    <span className="member-email">{member.invited_email ?? member.user_id ?? 'Unknown'}{isSelf ? ' (you)' : ''}</span>
                    <div style={{ display: 'flex', gap: '6px', alignItems: 'center', marginTop: '3px' }}>
                      <span className="role-badge" style={{ color: role.color, background: role.bg }}>
                        {role.label}
                      </span>
                      {!member.accepted && (
                        <span className="pending-badge">Pending</span>
                      )}
                    </div>
                  </div>
                  {canManage && (
                    <div className="member-actions">
                      <select
                        className="role-select-inline"
                        value={member.role}
                        onChange={e => updateRole(member, e.target.value as 'editor' | 'viewer')}
                        disabled={updatingId === member.id}
                      >
                        <option value="editor">Editor</option>
                        <option value="viewer">Viewer</option>
                      </select>
                      <button
                        className="btn-remove-member"
                        onClick={() => removeMember(member)}
                        disabled={updatingId === member.id}
                        title="Remove member"
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  )}
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
}
