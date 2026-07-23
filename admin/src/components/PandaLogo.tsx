export function PandaLogo({ size = 40, showWordmark = true }: { size?: number; showWordmark?: boolean }) {
  const mark = (
    <div
      className="flex items-center justify-center bg-panda-laranja text-white shrink-0"
      style={{ width: size, height: size, borderRadius: size * 0.28, fontSize: size * 0.55 }}
    >
      🐼
    </div>
  );
  if (!showWordmark) return mark;
  return (
    <div className="flex items-center gap-2">
      {mark}
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
