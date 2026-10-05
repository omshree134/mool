import React from 'react';

interface GroundedCardProps {
  children: React.ReactNode;
  className?: string;
  variant?: 'primary' | 'secondary' | 'dusk' | 'mist';
  elevation?: 'flat' | 'ground' | 'floating';
}

export const GroundedCard: React.FC<GroundedCardProps> = ({
  children,
  className = '',
  variant = 'primary',
  elevation = 'ground',
}) => {
  const bgClasses = {
    primary: 'bg-[#F9F7F1] border border-mool-mist text-mool-ink',
    secondary: 'bg-mool-linen border border-mool-mist/70 text-mool-ink',
    dusk: 'bg-mool-dusk text-mool-linen border border-mool-dusk-light',
    mist: 'bg-mool-mist/40 border border-mool-mist text-mool-ink',
  }[variant];

  const shadowClasses = {
    flat: '',
    ground: 'shadow-soft-ground',
    floating: 'shadow-dusk-elevated',
  }[elevation];

  return (
    <div className={`rounded-organic-lg p-5 sm:p-6 transition-all duration-300 ${bgClasses} ${shadowClasses} ${className}`}>
      {children}
    </div>
  );
};

