import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Construct-IQ — Modern Construction Intelligence",
  description: "A high-end, minimal agency experience for construction intelligence, takeoffs, and bidding.",
  icons: [{ rel: "icon", url: "/favicon.svg" }],
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3001"),
  openGraph: {
    title: "Construct-IQ",
    description: "Modern construction intelligence, foundation → roof.",
    url: process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3001",
    siteName: "Construct-IQ",
    images: [{ url: "/og.png", width: 1200, height: 630 }],
    type: "website"
  },
  twitter: { card: "summary_large_image", title: "Construct-IQ", description: "Modern construction intelligence." }
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <div className="min-h-screen flex flex-col">
          <header className="border-b border-line/60">
            <div className="container h-16 flex items-center justify-between">
              <a href="/" className="flex items-center gap-2">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
                  <rect x="2" y="2" width="20" height="20" rx="5" stroke="currentColor" opacity="0.25"/>
                  <path d="M6 15l4-6 4 3 4-4" stroke="#16f1b7" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
                <span className="font-semibold tracking-tight">Construct-IQ</span>
              </a>
              <nav className="hidden md:flex items-center gap-6 text-sm">
                <a className="link" href="#work">Work</a>
                <a className="link" href="#services">Services</a>
                <a className="link" href="#about">About</a>
                <a className="btn-outline" href="#contact">Contact</a>
              </nav>
            </div>
          </header>
          <main className="flex-1">{children}</main>
          <footer className="border-t border-line/60">
            <div className="container py-8 text-sm text-mute flex items-center justify-between">
              <span>© {new Date().getFullYear()} Construct-IQ</span>
              <div className="flex gap-4">
                <a className="link" href="#">Privacy</a>
                <a className="link" href="#">Terms</a>
              </div>
            </div>
          </footer>
        </div>
      </body>
    </html>
  );
}
