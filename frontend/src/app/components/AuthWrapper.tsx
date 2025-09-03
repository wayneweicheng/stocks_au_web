"use client";

import { useAuth } from '../contexts/AuthContext';
import LoginForm from './LoginForm';

export default function AuthWrapper({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuth();

  if (!isAuthenticated) {
    return <LoginForm />;
  }

  return <>{children}</>;
}