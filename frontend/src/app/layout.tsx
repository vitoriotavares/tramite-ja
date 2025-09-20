import type { Metadata } from "next";
import { Kanit, Maitree, Fira_Code } from "next/font/google";
import { ServerSidebar } from "@/components/ServerSidebar";
import "./globals.css";

const kanit = Kanit({
  variable: "--font-sans",
  subsets: ["latin"],
  weight: ["300", "400", "500", "600", "700"],
});

const maitree = Maitree({
  variable: "--font-serif",
  subsets: ["latin"],
  weight: ["200", "300", "400", "500", "600", "700"],
});

const firaCode = Fira_Code({
  variable: "--font-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "TrâmiteJá - Plataforma Digital de Defesa de Trânsito",
  description: "Plataforma oficial para recursos de multas de trânsito. Processo transparente, seguro e com acompanhamento em tempo real.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-BR">
      <body
        className={`${kanit.variable} ${maitree.variable} ${firaCode.variable} font-sans antialiased`}
        suppressHydrationWarning={true}
      >
        <ServerSidebar>
          {children}
        </ServerSidebar>
      </body>
    </html>
  );
}
