"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth, DEFAULT_USERS } from "@/context/AuthContext";
import { db, ref, set, get } from "@/lib/firebase";
import QRScannerModal from "@/components/QRScannerModal";
import {
  GraduationCap,
  Lock,
  User,
  ShieldAlert,
  CheckCircle,
  Key,
  BookOpen,
  ArrowRight,
  Sparkles,
  LogIn,
  UserPlus,
  QrCode,
  Camera
} from "lucide-react";

export default function LoginPage() {
  const router = useRouter();
  const { login } = useAuth();

  const [isRegister, setIsRegister] = useState(false);
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [role, setRole] = useState("STUDENT"); // STUDENT, TEACHER, ADMIN
  const [adminCode, setAdminCode] = useState("");
  const [subject, setSubject] = useState("TOAN");
  const [errorMsg, setErrorMsg] = useState("");
  const [successMsg, setSuccessMsg] = useState("");

  // QR Scanner Modal State
  const [showScannerModal, setShowScannerModal] = useState(false);

  // Check URL query parameters for QR Auto-Login
  useEffect(() => {
    if (typeof window === "undefined") return;
    const urlParams = new URLSearchParams(window.location.search);
    const qrUser = urlParams.get("qr_user");
    const name = urlParams.get("name");

    if (qrUser) {
      const studentSession = {
        username: `student_${qrUser}`,
        name: name || `Học sinh #${qrUser}`,
        role: "STUDENT",
      };
      login(studentSession);
      setSuccessMsg(`🎉 Đã nhận diện thẻ học sinh: ${studentSession.name}! Đang chuyển vào trang làm bài thi...`);
      setTimeout(() => router.push("/de-thi"), 600);
    }
  }, []);

  // Handle QR Camera Scan Success
  const handleQRScanSuccess = (decodedText) => {
    setShowScannerModal(false);

    let studentData = {
      username: "student_qr",
      name: "Học sinh",
      role: "STUDENT",
    };

    try {
      const parsed = JSON.parse(decodedText);
      if (parsed.type === "TUITION_STUDENT_QR") {
        studentData = {
          username: `student_${parsed.id}`,
          name: parsed.name || "Học sinh",
          role: "STUDENT",
          classId: parsed.classId,
        };
      } else {
        studentData = {
          username: `student_${decodedText}`,
          name: `Học sinh #${decodedText}`,
          role: "STUDENT",
        };
      }
    } catch (e) {
      studentData = {
        username: `student_${decodedText}`,
        name: `Học sinh #${decodedText}`,
        role: "STUDENT",
      };
    }

    login(studentData);
    setSuccessMsg(`🎉 Quét mã thành công! Đã đăng nhập tự động học sinh: ${studentData.name}`);
    setTimeout(() => router.push("/de-thi"), 600);
  };

  // Handle Login Form Submit
  const handleLoginSubmit = async (e) => {
    e.preventDefault();
    setErrorMsg("");
    setSuccessMsg("");

    if (!username || !password) {
      setErrorMsg("Vui lòng nhập đầy đủ Tên đăng nhập và Mật khẩu!");
      return;
    }

    try {
      // Check Firebase DB for user
      const userRef = ref(db, `tai_khoan/${username}`);
      const snapshot = await get(userRef);

      let userData = null;
      if (snapshot.exists()) {
        userData = snapshot.val();
      } else {
        // Fallback check demo accounts
        const matchDemo = Object.values(DEFAULT_USERS).find(
          (u) => u.username === username && u.password === password
        );
        if (matchDemo) {
          userData = matchDemo;
        }
      }

      if (userData && userData.password === password) {
        login(userData);
        setSuccessMsg(`Đăng nhập thành công với vai trò ${userData.role}!`);
        setTimeout(() => {
          if (userData.role === "STUDENT") {
            router.push("/de-thi");
          } else {
            router.push("/");
          }
        }, 500);
      } else {
        setErrorMsg("Tên đăng nhập hoặc mật khẩu không chính xác!");
      }
    } catch (err) {
      console.error("Lỗi khi đăng nhập:", err);
      setErrorMsg("Đã xảy ra lỗi hệ thống khi kết nối CSDL.");
    }
  };

  // Handle Register Form Submit
  const handleRegisterSubmit = async (e) => {
    e.preventDefault();
    setErrorMsg("");
    setSuccessMsg("");

    if (!username || !password || !fullName) {
      setErrorMsg("Vui lòng điền đầy đủ các thông tin bắt buộc!");
      return;
    }

    if (role === "ADMIN" && adminCode !== "admin141" && adminCode !== "admin123") {
      setErrorMsg("Mã xác thực Admin không đúng! (Mã mặc định: admin141)");
      return;
    }

    const newUser = {
      username: username.trim().toLowerCase(),
      password: password.trim(),
      name: fullName.trim(),
      phone: phone.trim(),
      role,
      subject: role === "TEACHER" ? subject : "ALL",
      created_at: new Date().toISOString(),
    };

    try {
      const userRef = ref(db, `tai_khoan/${newUser.username}`);
      await set(userRef, newUser);

      login(newUser);
      setSuccessMsg("Tạo tài khoản thành công! Đang chuyển hướng...");

      setTimeout(() => {
        if (role === "STUDENT") {
          router.push("/de-thi");
        } else {
          router.push("/");
        }
      }, 600);
    } catch (err) {
      console.error("Lỗi khi đăng ký:", err);
      setErrorMsg("Không thể lưu tài khoản vào CSDL.");
    }
  };

  // Quick Switch Roles for Testing
  const handleQuickLogin = (roleType) => {
    if (roleType === "ADMIN") {
      login(DEFAULT_USERS.admin);
      router.push("/");
    } else if (roleType === "TEACHER") {
      login(DEFAULT_USERS.teacher);
      router.push("/");
    } else if (roleType === "STUDENT") {
      login(DEFAULT_USERS.student);
      router.push("/de-thi");
    }
  };

  return (
    <div
      style={{
        minHeight: "85vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: "1rem",
      }}
    >
      <div
        style={{
          width: "100%",
          maxWidth: "480px",
          backgroundColor: "var(--bg-card)",
          borderRadius: "var(--radius-lg)",
          border: "1px solid var(--border-color)",
          padding: "2rem",
          boxShadow: "0 10px 40px rgba(0,0,0,0.3)",
        }}
      >
        {/* Logo & Header Title */}
        <div style={{ textAlign: "center", marginBottom: "1.5rem" }}>
          <div
            style={{
              width: "56px",
              height: "56px",
              borderRadius: "16px",
              background: "var(--accent-gradient)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              margin: "0 auto 0.75rem auto",
              boxShadow: "0 4px 20px var(--accent-glow)",
            }}
          >
            <GraduationCap size={32} color="#ffffff" />
          </div>
          <h2 style={{ fontSize: "1.4rem", fontWeight: "800", letterSpacing: "-0.5px" }}>
            HỆ THỐNG TUITION 2026
          </h2>
          <p style={{ fontSize: "0.85rem", color: "var(--text-muted)", marginTop: "0.25rem" }}>
            CƠ SỞ DẠY THÊM - HỌC THÊM 141 NGUYỄN THIỆN KẾ
          </p>
        </div>

        {/* PROMINENT QR CODE LOGIN BUTTON FOR STUDENTS */}
        <button
          type="button"
          onClick={() => setShowScannerModal(true)}
          style={{
            width: "100%",
            padding: "0.85rem 1rem",
            borderRadius: "14px",
            border: "2px solid var(--accent-primary)",
            backgroundColor: "rgba(13, 148, 136, 0.15)",
            color: "var(--accent-primary)",
            fontWeight: "800",
            fontSize: "0.95rem",
            cursor: "pointer",
            marginBottom: "1.5rem",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: "0.6rem",
            boxShadow: "0 4px 15px var(--accent-glow)",
          }}
        >
          <Camera size={22} />
          <span>📷 QUÉT MÃ QR THẺ HỌC SINH (ĐĂNG NHẬP NHANH)</span>
        </button>

        {/* Tab Switcher: Login / Register */}
        <div
          style={{
            display: "flex",
            backgroundColor: "var(--bg-primary)",
            padding: "0.25rem",
            borderRadius: "12px",
            marginBottom: "1.5rem",
            border: "1px solid var(--border-color)",
          }}
        >
          <button
            type="button"
            onClick={() => {
              setIsRegister(false);
              setErrorMsg("");
            }}
            style={{
              flex: 1,
              padding: "0.6rem",
              borderRadius: "10px",
              border: "none",
              backgroundColor: !isRegister ? "var(--accent-primary)" : "transparent",
              color: !isRegister ? "#ffffff" : "var(--text-secondary)",
              fontWeight: "700",
              fontSize: "0.9rem",
              cursor: "pointer",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              gap: "0.4rem",
              transition: "all 0.2s ease",
            }}
          >
            <LogIn size={16} /> Đăng Nhập
          </button>

          <button
            type="button"
            onClick={() => {
              setIsRegister(true);
              setErrorMsg("");
            }}
            style={{
              flex: 1,
              padding: "0.6rem",
              borderRadius: "10px",
              border: "none",
              backgroundColor: isRegister ? "var(--accent-primary)" : "transparent",
              color: isRegister ? "#ffffff" : "var(--text-secondary)",
              fontWeight: "700",
              fontSize: "0.9rem",
              cursor: "pointer",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              gap: "0.4rem",
              transition: "all 0.2s ease",
            }}
          >
            <UserPlus size={16} /> Đăng Ký
          </button>
        </div>

        {/* Alerts */}
        {errorMsg && (
          <div
            style={{
              backgroundColor: "rgba(239, 68, 68, 0.15)",
              border: "1px solid rgba(239, 68, 68, 0.3)",
              color: "var(--danger)",
              padding: "0.75rem 1rem",
              borderRadius: "10px",
              fontSize: "0.85rem",
              marginBottom: "1.25rem",
              display: "flex",
              alignItems: "center",
              gap: "0.5rem",
              fontWeight: "600",
            }}
          >
            <ShieldAlert size={18} /> {errorMsg}
          </div>
        )}

        {successMsg && (
          <div
            style={{
              backgroundColor: "rgba(16, 185, 129, 0.15)",
              border: "1px solid rgba(16, 185, 129, 0.3)",
              color: "var(--success)",
              padding: "0.75rem 1rem",
              borderRadius: "10px",
              fontSize: "0.85rem",
              marginBottom: "1.25rem",
              display: "flex",
              alignItems: "center",
              gap: "0.5rem",
              fontWeight: "600",
            }}
          >
            <CheckCircle size={18} /> {successMsg}
          </div>
        )}

        {/* LOGIN FORM */}
        {!isRegister ? (
          <form onSubmit={handleLoginSubmit} style={{ display: "flex", flexDirection: "column", gap: "1.1rem" }}>
            <div>
              <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                Tên Đăng Nhập
              </label>
              <div style={{ position: "relative" }}>
                <User size={18} style={{ position: "absolute", left: "0.85rem", top: "50%", transform: "translateY(-50%)", color: "var(--text-muted)" }} />
                <input
                  type="text"
                  required
                  placeholder="Nhập tên đăng nhập (ví dụ: student)..."
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  style={{
                    width: "100%",
                    padding: "0.75rem 0.75rem 0.75rem 2.5rem",
                    borderRadius: "var(--radius-md)",
                    backgroundColor: "var(--bg-primary)",
                    border: "1px solid var(--border-color)",
                    color: "var(--text-primary)",
                    outline: "none",
                    fontWeight: "600",
                  }}
                />
              </div>
            </div>

            <div>
              <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                Mật Khẩu
              </label>
              <div style={{ position: "relative" }}>
                <Lock size={18} style={{ position: "absolute", left: "0.85rem", top: "50%", transform: "translateY(-50%)", color: "var(--text-muted)" }} />
                <input
                  type="password"
                  required
                  placeholder="Nhập mật khẩu (ví dụ: 123)..."
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  style={{
                    width: "100%",
                    padding: "0.75rem 0.75rem 0.75rem 2.5rem",
                    borderRadius: "var(--radius-md)",
                    backgroundColor: "var(--bg-primary)",
                    border: "1px solid var(--border-color)",
                    color: "var(--text-primary)",
                    outline: "none",
                    fontWeight: "600",
                  }}
                />
              </div>
            </div>

            <button
              type="submit"
              className="btn-primary"
              style={{
                padding: "0.85rem",
                borderRadius: "var(--radius-md)",
                fontWeight: "800",
                fontSize: "0.95rem",
                marginTop: "0.5rem",
                boxShadow: "0 4px 15px var(--accent-glow)",
              }}
            >
              ĐĂNG NHẬP HỆ THỐNG
            </button>
          </form>
        ) : (
          /* REGISTER FORM */
          <form onSubmit={handleRegisterSubmit} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
            <div>
              <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                Chọn Vai Trò Đăng Ký *
              </label>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "0.5rem" }}>
                <button
                  type="button"
                  onClick={() => setRole("STUDENT")}
                  style={{
                    padding: "0.6rem 0.4rem",
                    borderRadius: "10px",
                    border: role === "STUDENT" ? "2px solid var(--accent-primary)" : "1px solid var(--border-color)",
                    backgroundColor: role === "STUDENT" ? "rgba(13, 148, 136, 0.15)" : "var(--bg-primary)",
                    color: role === "STUDENT" ? "var(--accent-primary)" : "var(--text-secondary)",
                    fontWeight: "700",
                    fontSize: "0.8rem",
                    cursor: "pointer",
                  }}
                >
                  🎓 Học Sinh
                </button>

                <button
                  type="button"
                  onClick={() => setRole("TEACHER")}
                  style={{
                    padding: "0.6rem 0.4rem",
                    borderRadius: "10px",
                    border: role === "TEACHER" ? "2px solid var(--warning)" : "1px solid var(--border-color)",
                    backgroundColor: role === "TEACHER" ? "rgba(245, 158, 11, 0.15)" : "var(--bg-primary)",
                    color: role === "TEACHER" ? "var(--warning)" : "var(--text-secondary)",
                    fontWeight: "700",
                    fontSize: "0.8rem",
                    cursor: "pointer",
                  }}
                >
                  👨‍🏫 Giáo Viên
                </button>

                <button
                  type="button"
                  onClick={() => setRole("ADMIN")}
                  style={{
                    padding: "0.6rem 0.4rem",
                    borderRadius: "10px",
                    border: role === "ADMIN" ? "2px solid var(--danger)" : "1px solid var(--border-color)",
                    backgroundColor: role === "ADMIN" ? "rgba(239, 68, 68, 0.15)" : "var(--bg-primary)",
                    color: role === "ADMIN" ? "var(--danger)" : "var(--text-secondary)",
                    fontWeight: "700",
                    fontSize: "0.8rem",
                    cursor: "pointer",
                  }}
                >
                  👑 Admin
                </button>
              </div>
            </div>

            <div>
              <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.3rem" }}>
                Họ và Tên *
              </label>
              <input
                type="text"
                required
                placeholder="Ví dụ: Nguyễn Văn An"
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                style={{
                  width: "100%",
                  padding: "0.65rem",
                  borderRadius: "var(--radius-md)",
                  backgroundColor: "var(--bg-primary)",
                  border: "1px solid var(--border-color)",
                  color: "var(--text-primary)",
                  outline: "none",
                  fontSize: "0.9rem",
                }}
              />
            </div>

            <div>
              <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.3rem" }}>
                Tên Đăng Nhập *
              </label>
              <input
                type="text"
                required
                placeholder="Viết liền không dấu..."
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                style={{
                  width: "100%",
                  padding: "0.65rem",
                  borderRadius: "var(--radius-md)",
                  backgroundColor: "var(--bg-primary)",
                  border: "1px solid var(--border-color)",
                  color: "var(--text-primary)",
                  outline: "none",
                  fontSize: "0.9rem",
                }}
              />
            </div>

            <div>
              <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.3rem" }}>
                Mật Khẩu *
              </label>
              <input
                type="password"
                required
                placeholder="Nhập mật khẩu tự chọn..."
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                style={{
                  width: "100%",
                  padding: "0.65rem",
                  borderRadius: "var(--radius-md)",
                  backgroundColor: "var(--bg-primary)",
                  border: "1px solid var(--border-color)",
                  color: "var(--text-primary)",
                  outline: "none",
                  fontSize: "0.9rem",
                }}
              />
            </div>

            {role === "TEACHER" && (
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.3rem" }}>
                  Môn Phụ Trách Giảng Dạy *
                </label>
                <select
                  value={subject}
                  onChange={(e) => setSubject(e.target.value)}
                  style={{
                    width: "100%",
                    padding: "0.65rem",
                    borderRadius: "var(--radius-md)",
                    backgroundColor: "var(--bg-primary)",
                    border: "1px solid var(--border-color)",
                    color: "var(--text-primary)",
                    outline: "none",
                  }}
                >
                  <option value="TOAN">📐 Môn TOÁN</option>
                  <option value="KHTN">🔬 Môn KHTN</option>
                  <option value="VAT_LI">⚡ Môn VẬT LÍ</option>
                </select>
              </div>
            )}

            {role === "ADMIN" && (
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.3rem", color: "var(--danger)" }}>
                  Mã Bảo Mật Của Admin *
                </label>
                <input
                  type="password"
                  required
                  placeholder="Nhập mã bảo mật (Ví dụ: admin141)..."
                  value={adminCode}
                  onChange={(e) => setAdminCode(e.target.value)}
                  style={{
                    width: "100%",
                    padding: "0.65rem",
                    borderRadius: "var(--radius-md)",
                    backgroundColor: "var(--bg-primary)",
                    border: "1px dashed var(--danger)",
                    color: "var(--text-primary)",
                    outline: "none",
                  }}
                />
              </div>
            )}

            <button
              type="submit"
              className="btn-primary"
              style={{
                padding: "0.85rem",
                borderRadius: "var(--radius-md)",
                fontWeight: "800",
                fontSize: "0.95rem",
                marginTop: "0.5rem",
                backgroundColor: "var(--success)",
              }}
            >
              HOÀN TẤT ĐĂNG KÝ
            </button>
          </form>
        )}

        {/* DEMO QUICK LOGIN BUTTONS */}
        <div style={{ marginTop: "1.75rem", borderTop: "1px solid var(--border-color)", paddingTop: "1.25rem" }}>
          <div style={{ fontSize: "0.8rem", fontWeight: "700", color: "var(--text-muted)", marginBottom: "0.75rem", textAlign: "center" }}>
            ⚡ ĐĂNG NHẬP NHANH DEMO (1-CLICK DỄ THỬ NGHIỆM):
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem" }}>
            <button
              type="button"
              onClick={() => handleQuickLogin("ADMIN")}
              style={{
                padding: "0.6rem 0.85rem",
                borderRadius: "10px",
                border: "1px solid rgba(239, 68, 68, 0.3)",
                backgroundColor: "rgba(239, 68, 68, 0.1)",
                color: "var(--danger)",
                fontWeight: "700",
                fontSize: "0.82rem",
                cursor: "pointer",
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
              }}
            >
              <span>👑 Demo Vai Trò ADMIN (Toàn quyền quản trị)</span>
              <ArrowRight size={16} />
            </button>

            <button
              type="button"
              onClick={() => handleQuickLogin("TEACHER")}
              style={{
                padding: "0.6rem 0.85rem",
                borderRadius: "10px",
                border: "1px solid rgba(245, 158, 11, 0.3)",
                backgroundColor: "rgba(245, 158, 11, 0.1)",
                color: "var(--warning)",
                fontWeight: "700",
                fontSize: "0.82rem",
                cursor: "pointer",
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
              }}
            >
              <span>👨‍🏫 Demo Vai Trò GIÁO VIÊN (Quản lý lớp dạy)</span>
              <ArrowRight size={16} />
            </button>

            <button
              type="button"
              onClick={() => handleQuickLogin("STUDENT")}
              style={{
                padding: "0.6rem 0.85rem",
                borderRadius: "10px",
                border: "1px solid rgba(13, 148, 136, 0.3)",
                backgroundColor: "rgba(13, 148, 136, 0.1)",
                color: "var(--accent-primary)",
                fontWeight: "700",
                fontSize: "0.82rem",
                cursor: "pointer",
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
              }}
            >
              <span>🎓 Demo Vai Trò HỌC SINH (Làm bài thi & BTVN)</span>
              <ArrowRight size={16} />
            </button>
          </div>
        </div>
      </div>

      {/* CAMERA QR SCANNER MODAL */}
      {showScannerModal && (
        <QRScannerModal
          onClose={() => setShowScannerModal(false)}
          onScanSuccess={handleQRScanSuccess}
        />
      )}
    </div>
  );
}
