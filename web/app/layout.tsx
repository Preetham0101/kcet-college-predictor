import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "KCET College Predictor",
  description: "Compare your KCET rank with historical cutoff data.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
