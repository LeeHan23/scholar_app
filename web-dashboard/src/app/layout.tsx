import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'ScholarSync',
  description: 'Smart Paper Management and Research Queue',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
