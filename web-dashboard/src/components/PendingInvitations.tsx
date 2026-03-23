"use client";

import { useState, useEffect } from 'react';
import { Users, ChevronDown, ChevronUp, Check, X } from 'lucide-react';
import { supabase } from '../lib/supabaseClient';

interface PendingInvitation {
  id: number;
  project_id: number;
  role: 'owner' | 'editor' | 'viewer';
  invited_email: string;
  accepted: boolean;
  projects: { name: string } | null;
}

interface Props {
  userId: string;
  userEmail: string;
  onAccepted: () => void;
}

export default function PendingInvitations({ userId, userEmail, onAccepted }: Props) {
  const [invitations, setInvitations] = useState<PendingInvitation[]>([]);
  const [expanded, setExpanded] = useState(true);
  const [processingId, setProcessingId] = useState<number | null>(null);

  useEffect(() => {
    if (userEmail) fetchInvitations();
  }, [userEmail]);

  const fetchInvitations = async () => {
    const { data } = await supabase
      .from('project_members')
      .select('*, projects(name)')
      .eq('invited_email', userEmail)
      .eq('accepted', false);
    setInvitations((data ?? []) as PendingInvitation[]);
  };

  const accept = async (inv: PendingInvitation) => {
    setProcessingId(inv.id);
    const { error } = await supabase
      .from('project_members')
      .update({ accepted: true, user_id: userId })
      .eq('id', inv.id);
    if (!error) {
      setInvitations(prev => prev.filter(i => i.id !== inv.id));
      onAccepted();
    }
    setProcessingId(null);
  };

  const decline = async (inv: PendingInvitation) => {
    setProcessingId(inv.id);
    const { error } = await supabase
      .from('project_members')
      .delete()
      .eq('id', inv.id);
    if (!error) {
      setInvitations(prev => prev.filter(i => i.id !== inv.id));
    }
    setProcessingId(null);
  };

  if (invitations.length === 0) return null;

  return (
    <div className="pending-invitations-banner">
      <button
        className="pending-invitations-header"
        onClick={() => setExpanded(e => !e)}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <Users size={18} color="var(--warning)" />
          <span style={{ fontWeight: 600, color: 'var(--warning)' }}>
            {invitations.length} pending group invitation{invitations.length !== 1 ? 's' : ''}
          </span>
        </div>
        {expanded ? <ChevronUp size={16} color="var(--warning)" /> : <ChevronDown size={16} color="var(--warning)" />}
      </button>

      {expanded && (
        <div className="pending-invitations-list">
          {invitations.map(inv => (
            <div key={inv.id} className="pending-invitation-item">
              <div className="pending-invitation-info">
                <span className="pending-project-name">{inv.projects?.name ?? 'Unknown Project'}</span>
                <span className="pending-role-label">Invited as {inv.role}</span>
              </div>
              <div className="pending-invitation-actions">
                <button
                  className="btn-accept"
                  onClick={() => accept(inv)}
                  disabled={processingId === inv.id}
                >
                  <Check size={14} />
                  Accept
                </button>
                <button
                  className="btn-decline"
                  onClick={() => decline(inv)}
                  disabled={processingId === inv.id}
                >
                  <X size={14} />
                  Decline
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
