import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import { onAuthStateChanged, signOut, type User } from "firebase/auth";
import { auth } from "../lib/firebase";
import { IS_DEMO, demoAdminUser } from "../lib/demo";

interface AuthState {
  user: User | null;
  isAdmin: boolean;
  loading: boolean;
  logout: () => Promise<void>;
}

const AuthCtx = createContext<AuthState>({
  user: null,
  isAdmin: false,
  loading: true,
  logout: async () => {},
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(
    IS_DEMO ? (demoAdminUser as unknown as User) : null
  );
  const [isAdmin, setIsAdmin] = useState(IS_DEMO);
  const [loading, setLoading] = useState(!IS_DEMO);

  useEffect(() => {
    if (IS_DEMO) return; // modo demo: admin fake, sem Firebase
    return onAuthStateChanged(auth, async (u) => {
      setUser(u);
      if (u) {
        // Lê a custom claim role=admin do token (setada por Cloud Function).
        const token = await u.getIdTokenResult(true);
        setIsAdmin(token.claims.role === "admin");
      } else {
        setIsAdmin(false);
      }
      setLoading(false);
    });
  }, []);

  return (
    <AuthCtx.Provider
      value={{ user, isAdmin, loading, logout: () => signOut(auth) }}
    >
      {children}
    </AuthCtx.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth() {
  return useContext(AuthCtx);
}
