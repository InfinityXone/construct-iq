import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(req: NextRequest) {
  // keep health open for uptime checks and deploy verifications
  if (req.nextUrl.pathname === '/api/health') return NextResponse.next();

  // place your protection/auth here if needed (Auth.js, headers, etc.)
  return NextResponse.next();
}

export const config = {
  // exclude next internals + favicon + health from protection
  matcher: ['/((?!_next|favicon|og\\.png|api/health).*)'],
};
