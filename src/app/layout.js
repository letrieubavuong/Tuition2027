"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import "./globals.css";
import {
  LayoutDashboard,
  Users,
  GraduationCap,
  CreditCard,
  CalendarCheck,
  Calendar,
  BarChart3,
  Trophy,
  Settings,
  Moon,
  Sun,
  Menu,
  X,
  Radio
} from "lucide-react";

export default function RootLayout({ children }) {
  const [theme, setTheme] = useState("dark");
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const pathname = usePathname();

  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
  }, [theme]);

  const toggleTheme = () => {
    setTheme((prev) => (prev === "dark" ? "light" : "dark"));
  };

  const navItems = [
    { name: "Trang Chủ", href: "/", icon: LayoutDashboard },
    { name: "Lớp Học", href: "/lop-hoc", icon: GraduationCap },
    { name: "Học Sinh", href: "/hoc-sinh", icon: Users },
    { name: "Điểm Danh", href: "/diem-danh", icon: CalendarCheck },
    { name: "Học Phí & VietQR", href: "/hoc-phi", icon: CreditCard },
    { name: "Lịch Dạy", href: "/lich-day", icon: Calendar },
    { name: "Thống Kê", href: "/thong-ke", icon: BarChart3 },
    { name: "Bảng Xếp Hạng", href: "/bang-xep-hang", icon: Trophy },
    { name: "Cài Đặt", href: "/cai-dat", icon: Settings },
  ];

  return (
    <html lang="vi">
      <head>
        <title>Tuition 2026 - Quản Lý Học Sinh & Học Phí</title>
        <meta name="description" content="Hệ thống quản lý học sinh và học phí realtime cho giáo viên" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
      </head>
      <body>
        <div style={{ display: "flex", minHeight: "100vh" }}>
          {/* Mobile Overlay */}
          {sidebarOpen && (
            <div
              onClick={() => setSidebarOpen(false)}
              style={{
                position: "fixed",
                inset: 0,
                backgroundColor: "rgba(0, 0, 0, 0.5)",
                zIndex: 40,
              }}
            />
          )}

          {/* Sidebar Navigation */}
          <aside
            style={{
              width: "260px",
              backgroundColor: "var(--bg-secondary)",
              borderRight: "1px solid var(--border-color)",
              display: "flex",
              flexDirection: "column",
              position: "fixed",
              top: 0,
              bottom: 0,
              left: 0,
              zIndex: 50,
              transform: sidebarOpen ? "translateX(0)" : "translateX(-100%)",
              transition: "transform 0.3s ease",
            }}
            className="sidebar-desktop"
          >
            {/* Logo */}
            <div
              style={{
                padding: "1.5rem",
                display: "flex",
                alignItems: "center",
                gap: "0.75rem",
                borderBottom: "1px solid var(--border-color)",
              }}
            >
              <div
                style={{
                  width: "42px",
                  height: "42px",
                  borderRadius: "12px",
                  background: "var(--accent-gradient)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  boxShadow: "0 4px 15px var(--accent-glow)",
                }}
              >
                <GraduationCap size={24} color="#ffffff" />
              </div>
              <div>
                <h1 style={{ fontSize: "1.2rem", fontWeight: "700", letterSpacing: "0.5px" }}>
                  Tuition 2026
                </h1>
                <p style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>
                  Quản lý Học sinh & Học phí
                </p>
              </div>
            </div>

            {/* Navigation Links */}
            <nav style={{ padding: "1.25rem 0.75rem", flex: 1 }}>
              <p
                style={{
                  fontSize: "0.7rem",
                  fontWeight: "700",
                  textTransform: "uppercase",
                  color: "var(--text-muted)",
                  paddingLeft: "0.75rem",
                  marginBottom: "0.75rem",
                  letterSpacing: "0.05em",
                }}
              >
                Menu Chính
              </p>
              {navItems.map((item) => {
                const Icon = item.icon;
                const isActive = pathname === item.href;
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    onClick={() => setSidebarOpen(false)}
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: "0.85rem",
                      padding: "0.8rem 1rem",
                      marginBottom: "0.35rem",
                      borderRadius: "var(--radius-md)",
                      color: isActive ? "#ffffff" : "var(--text-secondary)",
                      backgroundColor: isActive ? "var(--accent-primary)" : "transparent",
                      fontWeight: isActive ? "600" : "500",
                      textDecoration: "none",
                      boxShadow: isActive ? "0 4px 12px var(--accent-glow)" : "none",
                      transition: "all 0.2s ease",
                    }}
                  >
                    <Icon size={20} />
                    <span>{item.name}</span>
                  </Link>
                );
              })}
            </nav>

            {/* Realtime Status Footer */}
            <div
              style={{
                padding: "1rem 1.25rem",
                borderTop: "1px solid var(--border-color)",
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                <span
                  style={{
                    width: "10px",
                    height: "10px",
                    borderRadius: "50%",
                    backgroundColor: "var(--success)",
                    boxShadow: "0 0 10px var(--success)",
                    display: "inline-block",
                  }}
                />
                <span style={{ fontSize: "0.8rem", color: "var(--text-secondary)" }}>
                  Cloud Syncing
                </span>
              </div>
              <Radio size={16} color="var(--success)" />
            </div>
          </aside>

          {/* Main Layout Area */}
          <div style={{ flex: 1, display: "flex", flexDirection: "column" }} className="main-content">
            {/* Header Toolbar */}
            <header
              style={{
                height: "64px",
                backgroundColor: "var(--bg-card)",
                backdropFilter: "blur(16px)",
                borderBottom: "1px solid var(--border-color)",
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                padding: "0 1.5rem",
                position: "sticky",
                top: 0,
                zIndex: 30,
              }}
            >
              <button
                onClick={() => setSidebarOpen(!sidebarOpen)}
                style={{
                  background: "none",
                  border: "none",
                  color: "var(--text-primary)",
                  cursor: "pointer",
                  display: "flex",
                  alignItems: "center",
                }}
                className="mobile-toggle"
              >
                {sidebarOpen ? <X size={24} /> : <Menu size={24} />}
              </button>

              <div style={{ display: "flex", alignItems: "center", gap: "1rem", marginLeft: "auto" }}>
                <button
                  onClick={toggleTheme}
                  style={{
                    width: "40px",
                    height: "40px",
                    borderRadius: "50%",
                    border: "1px solid var(--border-color)",
                    backgroundColor: "var(--bg-secondary)",
                    color: "var(--text-primary)",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    cursor: "pointer",
                    transition: "var(--transition)",
                  }}
                  title="Chuyển chế độ Sáng/Tối"
                >
                  {theme === "dark" ? <Sun size={20} /> : <Moon size={20} />}
                </button>
              </div>
            </header>

            {/* Page Content */}
            <main style={{ padding: "1.75rem", flex: 1 }}>{children}</main>
          </div>
        </div>

        <style jsx global>{`
          @media (min-width: 768px) {
            .sidebar-desktop {
              transform: translateX(0) !important;
            }
            .main-content {
              margin-left: 260px;
            }
            .mobile-toggle {
              display: none !important;
            }
          }
        `}</style>
      </body>
    </html>
  );
}
