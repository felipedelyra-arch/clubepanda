import logoUrl from '../assets/logo.png';

/**
 * Logo oficial do Tio Panda / Clube Panda.
 * A imagem já contém a arte circular + texto "TioPanda".
 * Usa apenas `height` para definir o tamanho — a largura se ajusta
 * automaticamente via `object-fit: contain`, sem distorcer.
 */
export function PandaLogo({ size = 40 }: { size?: number; showWordmark?: boolean }) {
  return (
    <div style={{ width: size, height: size, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <img 
        src={logoUrl} 
        alt="Logo Clube Panda" 
        style={{ 
          width: '100%',
          height: '100%',
          objectFit: 'contain',
          display: 'block',
        }} 
      />
    </div>
  );
}
