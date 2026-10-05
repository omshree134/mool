import React from 'react';

interface TopographyDividerProps {
  className?: string;
  variant?: 'moss' | 'mist' | 'dusk';
}

export const TopographyDivider: React.FC<TopographyDividerProps> = ({ className = '', variant = 'mist' }) => {
  const strokeColor = {
    moss: '#5F7A5E',
    mist: '#E4E0D5',
    dusk: '#2E4452',
  }[variant];

  return (
    <div className={`w-full overflow-hidden leading-none py-2 ${className}`}>
      <svg
        viewBox="0 0 1200 60"
        preserveAspectRatio="none"
        className="w-full h-8 opacity-60"
        aria-hidden="true"
      >
        <path
          d="M0,0 C150,45 350,-20 500,30 C650,80 900,10 1200,25 L1200,60 L0,60 Z"
          fill={strokeColor}
          fillOpacity="0.15"
        />
        <path
          d="M0,20 C200,50 400,0 650,35 C900,70 1050,15 1200,40"
          fill="none"
          stroke={strokeColor}
          strokeWidth="1.5"
          strokeDasharray="4 4"
        />
      </svg>
    </div>
  );
};

