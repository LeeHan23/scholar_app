"use client";

import { useEffect } from 'react';
import { Auth } from '@supabase/auth-ui-react';
import { ThemeSupa } from '@supabase/auth-ui-shared';
import { supabase } from '@/lib/supabaseClient';

export default function Login() {
    useEffect(() => {
        // Redirect to dashboard if already logged in
        supabase.auth.getSession().then(({ data: { session } }) => {
            if (session?.user) {
                window.location.href = '/dashboard';
            }
        });

        // Listen for auth state changes (login success)
        const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
            if (session?.user) {
                window.location.href = '/dashboard';
            }
        });

        return () => subscription.unsubscribe();
    }, []);

    return (
        <div style={{ maxWidth: '400px', margin: '100px auto', padding: '20px' }}>
            <h1 className="title" style={{ textAlign: 'center', marginBottom: '20px' }}>Login to ScholarSync</h1>
            <Auth
                supabaseClient={supabase}
                appearance={{ theme: ThemeSupa }}
                providers={['github']}
                redirectTo="https://www.computationalrd.com/auth/confirm"
                theme="dark"
            />
        </div>
    );
}
