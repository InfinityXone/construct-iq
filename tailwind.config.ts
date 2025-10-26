import type { Config } from "tailwindcss"
export default {
  darkMode: ["class"],
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}", "./public/**/*.svg"],
  theme: {
    extend: {
      colors: {
        bg: "#0a0a0a",
        fg: "#ffffff",
        mute: "#b8b8b8",
        line: "#1a1a1a",
        brand: {
          DEFAULT: "#16f1b7",
          50:"#eafff8",100:"#c5ffe9",200:"#8dffd6",300:"#4affc3",400:"#16f1b7",
          500:"#0ac69a",600:"#089e7b",700:"#067a60",800:"#055d4a",900:"#044b3c"
        }
      },
      fontFamily: { sans: ["Inter","ui-sans-serif","system-ui","sans-serif"] },
      borderRadius: { xl2: "1.25rem" },
      boxShadow: { soft: "0 10px 30px rgba(0,0,0,0.35)" }
    }
  },
  plugins: []
} satisfies Config
