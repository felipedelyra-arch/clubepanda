import logoUrl from '../assets/logo.png';

export function PandaLogo({ size = 40, showWordmark = true }: { size?: number; showWordmark?: boolean }) {
  if (!showWordmark) {
    return <img src={logoUrl} alt="Logo" style={{ height: size, width: size, objectFit: 'contain' }} />;
  }

  return (
    <div className="flex items-center gap-2">
      <img src={logoUrl} alt="Clube Panda" style={{ height: size, objectFit: 'contain' }} />
      <div className="leading-tight">
        <div className="font-bold" style={{ fontSize: size * 0.42 }}>
          Clube Panda
        </div>
        <div className="text-panda-cinza-texto font-medium" style={{ fontSize: size * 0.26 }}>
          Tio Panda
        </div>
      </div>
    </div>
  );
}
