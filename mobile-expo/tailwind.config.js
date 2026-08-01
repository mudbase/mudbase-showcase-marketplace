/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: "class",
  content: ["./app/**/*.{ts,tsx}", "./src/**/*.{ts,tsx}"],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      colors: {
        // Same HSL-to-hex token conversion the sibling kanban port used
        // (web/src/app/globals.css's tokens, translated to hex) so this port reads as the
        // same product family as the web reference, just with this app's own mint-green/warm
        // palette instead of kanban's blue/purple one.
        background: { DEFAULT: "#fbfaf9", dark: "#101319" },
        foreground: { DEFAULT: "#181d25", dark: "#f3f0ed" },
        card: { DEFAULT: "#ffffff", dark: "#171a21" },
        primary: { DEFAULT: "#1d8663", foreground: "#fbfaf9", dark: "#37be91" },
        secondary: { DEFAULT: "#f1edea", foreground: "#181d25", dark: "#22272f" },
        muted: { DEFAULT: "#f1edea", foreground: "#606876", dark: "#22272f" },
        accent: { DEFAULT: "#f36f16", foreground: "#fbfaf9", dark: "#ef8239" },
        destructive: { DEFAULT: "#e42545", foreground: "#fbfaf9", dark: "#e05269" },
        border: { DEFAULT: "#e5e0dc", dark: "#2c313a" },
        success: "#1d8663",
        warning: "#b8790a",
      },
      borderRadius: {
        lg: "12px",
        md: "10px",
        sm: "8px",
      },
    },
  },
  plugins: [],
};
