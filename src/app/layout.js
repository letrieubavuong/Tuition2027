"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { AuthProvider, useAuth } from "@/context/AuthContext";
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
  Radio,
  FileText,
  LogOut,
  LogIn,
  ShieldAlert,
  UserCheck,
  ChevronRight
} from "lucide-react";

function AppLayout({ children }) {
  const [theme, setTheme] = useState("dark");
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const pathname = usePathname();
  const router = useRouter();
  const { user, logout, loading } = useAuth();

  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
  }, [theme]);

  const toggleTheme = () => {
    setTheme((prev) => (prev === "dark" ? "light" : "dark"));
  };

  const userRole = user ? user.role : "GUEST";

  // All Nav Items
  const allNavItems = [
    { name: "Trang Chủ", href: "/", icon: LayoutDashboard, roles: ["ADMIN", "TEACHER", "STUDENT"] },
    { name: "Lớp Học", href: "/lop-hoc", icon: GraduationCap, roles: ["ADMIN", "TEACHER"] },
    { name: "Học Sinh", href: "/hoc-sinh", icon: Users, roles: ["ADMIN", "TEACHER"] },
    { name: "Điểm Danh", href: "/diem-danh", icon: CalendarCheck, roles: ["ADMIN", "TEACHER"] },
    { name: "Đề Thi & BTVN", href: "/de-thi", icon: FileText, roles: ["ADMIN", "TEACHER", "STUDENT"] },
    { name: "Học Phí & VietQR", href: "/hoc-phi", icon: CreditCard, roles: ["ADMIN"] },
    { name: "Lịch Dạy & Học", href: "/lich-day", icon: Calendar, roles: ["ADMIN", "TEACHER", "STUDENT"] },
    { name: "Thống Kê", href: "/thong-ke", icon: BarChart3, roles: ["ADMIN"] },
    { name: "Bảng Xếp Hạng", href: "/bang-xep-hang", icon: Trophy, roles: ["ADMIN", "TEACHER", "STUDENT"] },
    { name: "Cài Đặt", href: "/cai-dat", icon: Settings, roles: ["ADMIN"] },
  ];

  // Filter Nav Items according to User Role
  const filteredNavItems = allNavItems.filter((item) => item.roles.includes(userRole));

  // Check if current route is allowed for current role
  const isLoginPage = pathname === "/login";
  const currentNavItem = allNavItems.find((item) => item.href === pathname);
  const isAccessDenied =
    !isLoginPage &&
    currentNavItem &&
    !currentNavItem.roles.includes(userRole);

  return (
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
            padding: "1.25rem 1.5rem",
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
            <h1 style={{ fontSize: "1.15rem", fontWeight: "800", letterSpacing: "0.5px" }}>
              Tuition 2026
            </h1>
            <p style={{ fontSize: "0.72rem", color: "var(--text-muted)" }}>
              141 NGUYỄN THIỆN KẾ
            </p>
          </div>
        </div>

        {/* User Role Card */}
        {user && (
          <div
            style={{
              margin: "0.85rem 0.75rem 0 0.75rem",
              padding: "0.75rem",
              borderRadius: "12px",
              backgroundColor: "var(--bg-card)",
              border: "1px solid var(--border-color)",
              display: "flex",
              alignItems: "center",
              gap: "0.65rem",
            }}
          >
            <div
              style={{
                width: "36px",
                height: "36px",
                borderRadius: "50%",
                backgroundColor:
                  user.role === "ADMIN"
                    ? "rgba(239, 68, 68, 0.2)"
                    : user.role === "TEACHER"
                    ? "rgba(245, 158, 11, 0.2)"
                    : "rgba(13, 148, 136, 0.2)",
                color:
                  user.role === "ADMIN"
                    ? "var(--danger)"
                    : user.role === "TEACHER"
                    ? "var(--warning)"
                    : "var(--accent-primary)",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                fontWeight: "800",
                fontSize: "0.9rem",
              }}
            >
              {user.name ? user.name.charAt(0) : "U"}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: "0.82rem", fontWeight: "700", textOverflow: "ellipsis", overflow: "hidden", whitespace: "nowrap" }}>
                {user.name}
              </div>
              <div
                style={{
                  fontSize: "0.68rem",
                  fontWeight: "800",
                  color:
                    user.role === "ADMIN"
                      ? "var(--danger)"
                      : user.role === "TEACHER"
                      ? "var(--warning)"
                      : "var(--accent-primary)",
                  display: "inline-block",
                  textTransform: "uppercase",
                }}
              >
                {user.role === "ADMIN" ? "👑 Admin" : user.role === "TEACHER" ? "👨‍🏫 Giáo viên" : "🎓 Học sinh"}
              </div>
            </div>
          </div>
        )}

        {/* Navigation Links */}
        <nav style={{ padding: "1rem 0.75rem", flex: 1, overflowY: "auto" }}>
          <p
            style={{
              fontSize: "0.7rem",
              fontWeight: "700",
              textTransform: "uppercase",
              color: "var(--text-muted)",
              paddingLeft: "0.75rem",
              marginBottom: "0.6rem",
              letterSpacing: "0.05em",
            }}
          >
            Menu Chức Năng
          </p>
          {filteredNavItems.map((item) => {
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
                  padding: "0.75rem 1rem",
                  marginBottom: "0.35rem",
                  borderRadius: "var(--radius-md)",
                  color: isActive ? "#ffffff" : "var(--text-secondary)",
                  backgroundColor: isActive ? "var(--accent-primary)" : "transparent",
                  fontWeight: isActive ? "700" : "500",
                  textDecoration: "none",
                  boxShadow: isActive ? "0 4px 12px var(--accent-glow)" : "none",
                  transition: "all 0.2s ease",
                }}
              >
                <Icon size={19} />
                <span style={{ fontSize: "0.9rem" }}>{item.name}</span>
              </Link>
            );
          })}
        </nav>

        {/* Realtime Status & Logout Footer */}
        <div
          style={{
            padding: "0.85rem 1rem",
            borderTop: "1px solid var(--border-color)",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
          }}
        >
          {user ? (
            <button
              type="button"
              onClick={() => {
                logout();
                router.push("/login");
              }}
              style={{
                width: "100%",
                padding: "0.55rem",
                borderRadius: "8px",
                border: "1px solid rgba(239, 68, 68, 0.3)",
                backgroundColor: "rgba(239, 68, 68, 0.1)",
                color: "var(--danger)",
                fontWeight: "700",
                fontSize: "0.82rem",
                cursor: "pointer",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                gap: "0.4rem",
              }}
            >
              <LogOut size={16} /> Đăng Xuất
            </button>
          ) : (
            <Link
              href="/login"
              style={{
                width: "100%",
                padding: "0.55rem",
                borderRadius: "8px",
                backgroundColor: "var(--accent-primary)",
                color: "#ffffff",
                fontWeight: "700",
                fontSize: "0.82rem",
                textDecoration: "none",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                gap: "0.4rem",
              }}
            >
              <LogIn size={16} /> Đăng Nhập
            </Link>
          )}
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

          <div style={{ display: "flex", alignItems: "center", gap: "0.85rem", marginLeft: "auto" }}>
            {/* User Role Badge in Header */}
            {user ? (
              <Link
                href="/login"
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: "0.5rem",
                  padding: "0.4rem 0.85rem",
                  borderRadius: "20px",
                  backgroundColor: "var(--bg-secondary)",
                  border: "1px solid var(--border-color)",
                  textDecoration: "none",
                  color: "var(--text-primary)",
                  fontSize: "0.82rem",
                  fontWeight: "600",
                }}
              >
                <UserCheck size={16} color="var(--accent-primary)" />
                <span>{user.name}</span>
                <span
                  style={{
                    fontSize: "0.7rem",
                    padding: "0.15rem 0.45rem",
                    borderRadius: "10px",
                    fontWeight: "800",
                    backgroundColor:
                      user.role === "ADMIN"
                        ? "rgba(239, 68, 68, 0.2)"
                        : user.role === "TEACHER"
                        ? "rgba(245, 158, 11, 0.2)"
                        : "rgba(13, 148, 136, 0.2)",
                    color:
                      user.role === "ADMIN"
                        ? "var(--danger)"
                        : user.role === "TEACHER"
                        ? "var(--warning)"
                        : "var(--accent-primary)",
                  }}
                >
                  {user.role}
                </span>
              </Link>
            ) : (
              <Link
                href="/login"
                className="btn-primary"
                style={{
                  padding: "0.45rem 1rem",
                  borderRadius: "20px",
                  fontSize: "0.85rem",
                  fontWeight: "700",
                  textDecoration: "none",
                }}
              >
                Đăng Nhập
              </Link>
            )}

            <button
              onClick={toggleTheme}
              style={{
                width: "38px",
                height: "38px",
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
              {theme === "dark" ? <Sun size={18} /> : <Moon size={18} />}
            </button>
          </div>
        </header>

        {/* Page Content & Route Guard */}
        <main style={{ padding: "1.75rem", flex: 1 }}>
          {isAccessDenied ? (
            <div
              style={{
                backgroundColor: "var(--bg-card)",
                borderRadius: "var(--radius-lg)",
                border: "1px solid var(--border-color)",
                padding: "3.5rem 1.5rem",
                textAlign: "center",
                maxWidth: "600px",
                margin: "3rem auto",
              }}
            >
              <ShieldAlert size={64} color="var(--danger)" style={{ marginBottom: "1rem" }} />
              <h2 style={{ fontSize: "1.4rem", fontWeight: "800", color: "var(--danger)" }}>
                Quyền Truy Cập Bị Hạn Chế
              </h2>
              <p style={{ color: "var(--text-muted)", fontSize: "0.9rem", marginTop: "0.5rem", lineHeight: "1.5" }}>
                Trang này không khả dụng cho tài khoản <strong>{userRole === "STUDENT" ? "Học sinh" : "Giáo viên"}</strong>.
                Học sinh chỉ có quyền truy cập Đề thi, Lịch học và Bảng xếp hạng.
              </p>

              <div style={{ display: "flex", justifyContent: "center", gap: "0.75rem", marginTop: "1.75rem" }}>
                <Link
                  href={userRole === "STUDENT" ? "/de-thi" : "/"}
                  className="btn-primary"
                  style={{
                    padding: "0.75rem 1.5rem",
                    borderRadius: "var(--radius-md)",
                    fontWeight: "700",
                    textDecoration: "none",
                  }}
                >
                  Quay Về Trang {userRole === "STUDENT" ? "Bài Thi" : "Chủ"}
                </Link>

                <Link
                  href="/login"
                  className="btn-secondary"
                  style={{
                    padding: "0.75rem 1.5rem",
                    borderRadius: "var(--radius-md)",
                    fontWeight: "600",
                    textDecoration: "none",
                  }}
                >
                  Đổi Tài Khoản Đăng Nhập
                </Link>
              </div>
            </div>
          ) : (
            children
          )}
        </main>
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
    </div>
  );
}

export default function RootLayout({ children }) {
  return (
    <html lang="vi">
      <head>
        <title>Tuition 2026 - CƠ SỞ DẠY THÊM - HỌC THÊM 141 NGUYỄN THIỆN KẾ</title>
        <meta name="description" content="Hệ thống quản lý học sinh, học phí và đề thi realtime cho giáo viên" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:ital,wght@0,300;0,400;0,500;0,600;0,700;0,800;0,900;1,300;1,400;1,600;1,700;1,800;1,900&display=swap"
          rel="stylesheet"
        />
        <link
          rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css"
        />
      </head>
      <body>
        <AuthProvider>
          <AppLayout>{children}</AppLayout>
        </AuthProvider>
      </body>
    </html>
  );
}
