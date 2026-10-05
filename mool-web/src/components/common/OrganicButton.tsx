import React from 'react';

interface OrganicButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'moss' | 'dusk' | 'sandrose' | 'ghost' | 'signal';
  size?: 'sm' | 'md' | 'lg';
  fullWidth?: boolean;
}

export const OrganicButton: React.FC<OrganicButtonProps> = ({
  children,
  variant = 'moss',
  size = 'md',
  fullWidth = false,
  className = '',
  ...props
}) => {
  const baseClasses = 'inline-flex items-center justify-center font-medium transition-all duration-200 focus-visible:ring-2 focus-visible:ring-offset-2 active:scale-[0.99] disabled:opacity-50 disabled:pointer-events-none rounded-organic';

  const sizeClasses = {
    sm: 'px-3 py-1.5 text-xs tracking-wide',
    md: 'px-5 py-2.5 text-sm tracking-wide',
    lg: 'px-6 py-3.5 text-base tracking-wide',
  }[size];

  const variantClasses = {
    moss: 'bg-mool-moss text-white hover:bg-mool-moss-dark focus-visible:ring-mool-moss',
    dusk: 'bg-mool-dusk text-white hover:bg-mool-dusk-dark focus-visible:ring-mool-dusk',
    sandrose: 'bg-mool-sandrose text-white hover:bg-opacity-90 focus-visible:ring-mool-sandrose',
    ghost: 'bg-transparent text-mool-ink hover:bg-mool-mist/50 border border-mool-mist focus-visible:ring-mool-ink',
    signal: 'bg-mool-signal text-white hover:bg-opacity-90 focus-visible:ring-mool-signal',
  }[variant];

  return (
    <button
      className={`${baseClasses} ${sizeClasses} ${variantClasses} ${fullWidth ? 'w-full' : ''} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
};

