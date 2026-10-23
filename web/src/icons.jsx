export function Logo({ size = 40 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" aria-hidden="true">
      <rect width="64" height="64" rx="16" fill="#1E6FE0" />
      <g fill="#fff">
        <rect x="14" y="26" width="6" height="12" rx="3" />
        <rect x="24" y="18" width="6" height="28" rx="3" />
        <rect x="34" y="12" width="6" height="40" rx="3" />
        <rect x="44" y="20" width="6" height="24" rx="3" />
      </g>
    </svg>
  );
}

const PATHS = {
  download: 'M12 3v12m0 0l-4.5-4.5M12 15l4.5-4.5M5 19h14',
  app: 'M5 5h5v5H5zM14 5h5v5h-5zM5 14h5v5H5zM14 14h5v5h-5z',
  play: 'M8 5v14l11-7z',
  chat: 'M4 5h16v11H9l-5 4z',
  swap: 'M7 7h12m0 0l-3-3m3 3l-3 3M17 17H5m0 0l3-3m-3 3l3 3',
  bell: 'M6 17V11a6 6 0 1 1 12 0v6l1.5 2h-15zM10 21h4',
  lock: 'M6 11h12v9H6zM8 11V8a4 4 0 0 1 8 0v3',
};

export function Icon({ name, size = 22 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor"
         strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={PATHS[name]} />
    </svg>
  );
}
