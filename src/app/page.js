"use client";

import { useEffect, useState } from "react";
import { db, ref, onValue, set, push } from "@/lib/firebase";
import { useAuth } from "@/context/AuthContext";
import {
  Users,
  GraduationCap,
  Calendar,
  CreditCard,
  TrendingUp,
  AlertCircle,
  Clock,
  ArrowUpRight,
  MapPin,
  Phone,
  Mail,
  Star,
  Send,
  CheckCircle2,
  Sparkles,
  BookOpen,
  MessageSquare,
  ShieldCheck,
  Award,
  School,
  Building2,
  Check,
  Search,
  ExternalLink,
  Edit
} from "lucide-react";
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend,
  ArcElement
} from "chart.js";
import { Bar, Doughnut } from "react-chartjs-2";

ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend,
  ArcElement
);

export default function CenterLandingPage() {
  const { user } = useAuth();
  const userRole = user ? user.role : "GUEST";
  const [activeTab, setActiveTab] = useState("public"); // "public" or "dashboard"
  const [selectedPhoto, setSelectedPhoto] = useState(null); // Photo Lightbox State

  // Admin Dashboard State
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({
    totalStudents: 0,
    totalClasses: 0,
    todaySessions: 0,
    totalCollected: 0,
    totalDebt: 0,
  });

  const [todaySchedule, setTodaySchedule] = useState([]);
  const [gradeDistribution, setGradeDistribution] = useState({});
  const [registrations, setRegistrations] = useState([]);

  // Reviews State
  const [reviews, setReviews] = useState([
    {
      id: "r1",
      ten: "Chị Nguyễn Thị Hoàng Yến",
      vai_tro: "Phụ huynh em Minh Đức - Khối 9",
      danh_gia: 5,
      noi_dung: "Thầy cô tại 141 Nguyễn Thiện Kế rất tận tâm. Sau 3 tháng học bồi dưỡng tại đây, con tôi đã tiến bộ rõ rệt môn Toán và Thi thử vào lớp 10 đạt 9.25 điểm!",
      ngay: "10/09/2026",
    },
    {
      id: "r2",
      ten: "Học sinh Lê Thanh Tùng",
      vai_tro: "Lớp 12 - Ôn thi THPT Quốc Gia",
      danh_gia: 5,
      noi_dung: "Cơ sở vật chất phòng học máy lạnh rất mát mẻ, thầy Vương giảng bài cực kỳ dễ hiểu và có ứng dụng theo sát điểm số rất tiện lợi ạ.",
      ngay: "08/09/2026",
    },
    {
      id: "r3",
      ten: "Anh Trần Văn Nam",
      vai_tro: "Phụ huynh em Bảo Anh - Khối 7",
      danh_gia: 5,
      noi_dung: "Trung tâm uy tín nhất khu vực Sơn Trà. Lớp học sĩ số vừa phải, giáo viên bám sát và có hệ thống thông báo điểm danh học phí minh bạch.",
      ngay: "01/09/2026",
    },
  ]);

  // Review Form State
  const [newReview, setNewReview] = useState({
    ten: "",
    vai_tro: "",
    danh_gia: 5,
    noi_dung: "",
  });
  const [submittingReview, setSubmittingReview] = useState(false);
  const [reviewMsg, setReviewMsg] = useState("");

  // Student Class Registration Form State
  const [regForm, setRegForm] = useState({
    ho_ten: "",
    khoi: "Khối 9",
    truong: "",
    sdt: "",
    mon_hoc: "Toán & Tiếng Anh",
    lich_mong_muon: "Tối T2 - T4 - T6 (17:30 - 19:00)",
    ghi_chu: "",
  });
  const [submittingReg, setSubmittingReg] = useState(false);
  const [regSuccessMsg, setRegSuccessMsg] = useState("");

  // Load Realtime Data from Firebase
  useEffect(() => {
    // 1. Students
    const hsRef = ref(db, "hoc_sinh");
    const unsubHs = onValue(hsRef, (snapshot) => {
      const val = snapshot.val();
      let count = 0;
      if (val) {
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        count = list.filter((s) => {
          if (!s) return false;
          const status = String(s.trang_thai || s.status || s.trangThai || "").toUpperCase();
          return status !== "DA_NGHI" && status !== "NGHI_HOC" && !s.da_nghi;
        }).length;
      }
      setStats((prev) => ({ ...prev, totalStudents: count }));
    });

    // 2. Classes
    const lopRef = ref(db, "lop");
    const unsubLop = onValue(lopRef, (snapshot) => {
      const val = snapshot.val();
      let count = 0;
      const grades = {};
      if (val) {
        const classList = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        count = classList.length;
        classList.forEach((c) => {
          const k = c.khoi ? `Khối ${c.khoi}` : "Khác";
          grades[k] = (grades[k] || 0) + 1;
        });
      }
      setGradeDistribution(grades);
      setStats((prev) => ({ ...prev, totalClasses: count }));
    });

    // 3. Tuition Payments
    const thanhToanRef = ref(db, "thanh_toan");
    const unsubThanhToan = onValue(thanhToanRef, (snapshot) => {
      const val = snapshot.val();
      let collected = 0;
      let debt = 0;
      if (val) {
        const records = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        records.forEach((r) => {
          const daDong = Number(r.so_tien_da_dong) || 0;
          const tong = Number(r.tong_thanh_toan) || 0;
          collected += daDong;
          if (tong > daDong) debt += tong - daDong;
        });
      }
      setStats((prev) => ({ ...prev, totalCollected: collected, totalDebt: debt }));
      setLoading(false);
    });

    // 4. Schedules
    const lichHocRef = ref(db, "lich_hoc_chung");
    const unsubLichHoc = onValue(lichHocRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        const todayWeekday = new Date().getDay() + 1;
        const filtered = list.filter((lh) => Number(lh.thu_trong_tuan || lh.thuTrongTuan) === todayWeekday);
        setTodaySchedule(filtered);
        setStats((prev) => ({ ...prev, todaySessions: filtered.length }));
      }
    });

    // 5. Reviews
    const reviewRef = ref(db, "danh_gia_trung_tam");
    const unsubReviews = onValue(reviewRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        setReviews(list.reverse());
      }
    });

    // 6. Registrations
    const regRef = ref(db, "dang_ky_lop_hoc");
    const unsubReg = onValue(regRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        setRegistrations(list.reverse());
      }
    });

    return () => {
      unsubHs();
      unsubLop();
      unsubThanhToan();
      unsubLichHoc();
      unsubReviews();
      unsubReg();
    };
  }, []);

  const formatCurrency = (num) => {
    return new Intl.NumberFormat("vi-VN", {
      style: "currency",
      currency: "VND",
    }).format(num || 0);
  };

  // Submit Student Registration Form
  const handleRegisterSubmit = async (e) => {
    e.preventDefault();
    if (!regForm.ho_ten || !regForm.sdt) {
      alert("Vui lòng nhập Họ tên học sinh và Số điện thoại liên hệ!");
      return;
    }
    setSubmittingReg(true);

    try {
      const regId = `DK_${Date.now()}`;
      const timestamp = new Date().toLocaleString("vi-VN");
      const newEntry = {
        id: regId,
        ...regForm,
        trang_thai: "CHO_XAC_NHAN",
        ngay_dang_ky: timestamp,
      };

      await set(ref(db, `dang_ky_lop_hoc/${regId}`), newEntry);

      setRegSuccessMsg(
        `Chúc mừng! Đăng ký lớp học của em ${regForm.ho_ten} đã được gửi thành công. Mã hồ sơ: ${regId}. Trung tâm 141 Nguyễn Thiện Kế sẽ gọi điện xác nhận trong vòng 24h!`
      );
      setRegForm({
        ho_ten: "",
        khoi: "Khối 9",
        truong: "",
        sdt: "",
        mon_hoc: "Toán & Tiếng Anh",
        lich_mong_muon: "Tối T2 - T4 - T6 (17:30 - 19:00)",
        ghi_chu: "",
      });
      setTimeout(() => setRegSuccessMsg(""), 8000);
    } catch (err) {
      alert("Lỗi khi đăng ký: " + err.message);
    } finally {
      setSubmittingReg(false);
    }
  };

  // Submit Center Review Form
  const handleReviewSubmit = async (e) => {
    e.preventDefault();
    if (!newReview.ten || !newReview.noi_dung) {
      alert("Vui lòng nhập Tên và Nội dung đánh giá!");
      return;
    }
    setSubmittingReview(true);

    try {
      const revId = `REV_${Date.now()}`;
      const timestamp = new Date().toLocaleDateString("vi-VN");
      const revEntry = {
        id: revId,
        ...newReview,
        ngay: timestamp,
      };

      await set(ref(db, `danh_gia_trung_tam/${revId}`), revEntry);
      setReviewMsg("Cảm ơn bạn đã gửi đánh giá quý báu về Trung tâm!");
      setNewReview({ ten: "", vai_tro: "", danh_gia: 5, noi_dung: "" });
      setTimeout(() => setReviewMsg(""), 5000);
    } catch (err) {
      alert("Lỗi gửi đánh giá: " + err.message);
    } finally {
      setSubmittingReview(false);
    }
  };

  const chartData = {
    labels: ["Đã Thu", "Còn Nợ"],
    datasets: [
      {
        data: [stats.totalCollected, stats.totalDebt],
        backgroundColor: ["#10b981", "#ef4444"],
        borderColor: ["rgba(16, 185, 129, 0.3)", "rgba(239, 68, 68, 0.3)"],
        borderWidth: 1,
      },
    ],
  };

  const gradeChartData = {
    labels: Object.keys(gradeDistribution),
    datasets: [
      {
        label: "Số lượng lớp học",
        data: Object.values(gradeDistribution),
        backgroundColor: "#0d9488",
        borderRadius: 8,
      },
    ],
  };

  return (
    <div>
      {/* 1. TOP HERO BANNER */}
      <div
        style={{
          background: "linear-gradient(135deg, rgba(13, 148, 136, 0.25) 0%, rgba(15, 23, 42, 0.8) 100%)",
          border: "1px solid var(--border-color)",
          borderRadius: "var(--radius-lg)",
          padding: "2rem 1.75rem",
          marginBottom: "1.5rem",
          position: "relative",
          overflow: "hidden",
        }}
      >
        <div style={{ position: "relative", zIndex: 2 }}>
          <div style={{ display: "flex", alignItems: "center", gap: "0.5rem", marginBottom: "0.75rem", flexWrap: "wrap" }}>
            <span
              style={{
                backgroundColor: "var(--accent-primary)",
                color: "#ffffff",
                padding: "0.25rem 0.75rem",
                borderRadius: "20px",
                fontSize: "0.75rem",
                fontWeight: "700",
                letterSpacing: "0.5px",
                textTransform: "uppercase",
              }}
            >
              Cơ sở Bồi dưỡng Văn hóa & Luyện thi Uy tín
            </span>
            <span
              style={{
                backgroundColor: "rgba(245, 158, 11, 0.2)",
                color: "var(--warning)",
                border: "1px solid var(--warning)",
                padding: "0.25rem 0.75rem",
                borderRadius: "20px",
                fontSize: "0.75rem",
                fontWeight: "600",
                display: "flex",
                alignItems: "center",
                gap: "0.3rem",
              }}
            >
              <Star size={12} fill="var(--warning)" /> Đánh giá 5.0 ★ Top Sơn Trà
            </span>
          </div>

          <h1
            style={{
              fontFamily: "'Be Vietnam Pro', sans-serif",
              fontSize: "2.1rem",
              fontWeight: "700",
              color: "#ffffff",
              lineHeight: "1.3",
              marginBottom: "0.75rem",
              textShadow: "0 2px 10px rgba(0,0,0,0.3)",
            }}
          >
            CƠ SỞ DẠY THÊM - HỌC THÊM 141 NGUYỄN THIỆN KẾ
          </h1>

          <p style={{ color: "var(--text-secondary)", fontSize: "1rem", maxWidth: "800px", lineHeight: "1.6", marginBottom: "1.25rem" }}>
            Chuyên Bồi dưỡng Kiến thức & Luyện thi Chất lượng cao các môn **Toán, Lý, Hóa, Văn, Tiếng Anh** cho Học sinh THCS & THPT. Đội ngũ giáo viên tận tâm, sĩ số giới hạn, theo sát năng lực từng em!
          </p>

          <div style={{ display: "flex", gap: "1rem", flexWrap: "wrap", alignItems: "center" }}>
            <div style={{ display: "flex", alignItems: "center", gap: "0.4rem", color: "var(--accent-primary)", fontSize: "0.9rem", fontWeight: "600" }}>
              <MapPin size={18} />
              <span>141 Nguyễn Thiện Kế, Sơn Trà, Đà Nẵng</span>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: "0.4rem", color: "var(--success)", fontSize: "0.9rem", fontWeight: "600" }}>
              <Phone size={18} />
              <span>Hotline / Zalo: 0905.073.175 - 0932.457.056</span>
            </div>
          </div>
        </div>
      </div>

      {/* 2. MODE TAB SWITCHER (PUBLIC LANDING vs MANAGEMENT DASHBOARD) */}
      <div
        style={{
          display: "flex",
          gap: "0.75rem",
          marginBottom: "1.75rem",
          borderBottom: "1px solid var(--border-color)",
          paddingBottom: "0.75rem",
          overflowX: "auto",
        }}
      >
        <button
          type="button"
          onClick={() => setActiveTab("public")}
          style={{
            padding: "0.75rem 1.35rem",
            borderRadius: "12px",
            border: activeTab === "public" ? "2px solid var(--accent-primary)" : "1px solid var(--border-color)",
            backgroundColor: activeTab === "public" ? "var(--accent-primary)" : "var(--bg-secondary)",
            color: activeTab === "public" ? "#ffffff" : "var(--text-primary)",
            fontWeight: "700",
            fontSize: "0.95rem",
            cursor: "pointer",
            display: "flex",
            alignItems: "center",
            gap: "0.6rem",
            boxShadow: activeTab === "public" ? "0 4px 14px var(--accent-glow)" : "none",
          }}
        >
          <School size={18} />
          <span>GIỚI THIỆU TRUNG TÂM & ĐĂNG KÝ HỌC</span>
        </button>

        {userRole !== "STUDENT" && (
          <button
            type="button"
            onClick={() => setActiveTab("dashboard")}
            style={{
              padding: "0.75rem 1.35rem",
              borderRadius: "12px",
              border: activeTab === "dashboard" ? "2px solid var(--accent-primary)" : "1px solid var(--border-color)",
              backgroundColor: activeTab === "dashboard" ? "var(--accent-primary)" : "var(--bg-secondary)",
              color: activeTab === "dashboard" ? "#ffffff" : "var(--text-primary)",
              fontWeight: "700",
              fontSize: "0.95rem",
              cursor: "pointer",
              display: "flex",
              alignItems: "center",
              gap: "0.6rem",
              boxShadow: activeTab === "dashboard" ? "0 4px 14px var(--accent-glow)" : "none",
            }}
          >
            <TrendingUp size={18} />
            <span>BẢNG QUẢN LÝ DÀNH CHO GIÁO VIÊN ({stats.totalStudents} HS)</span>
          </button>
        )}
      </div>

      {/* 3. PUBLIC CENTER WEBSITE TAB CONTENT */}
      {activeTab === "public" && (
        <div style={{ display: "flex", flexDirection: "column", gap: "2rem" }}>
          {/* SECTION 1: GIỚI THIỆU TRUNG TÂM & THÀNH TÍCH */}
          <div className="glass-panel" style={{ padding: "1.75rem" }}>
            <div style={{ display: "flex", alignItems: "center", gap: "0.6rem", marginBottom: "1.25rem" }}>
              <Award size={24} color="var(--accent-primary)" />
              <h3 style={{ fontFamily: "'Be Vietnam Pro', sans-serif", fontSize: "1.35rem", fontWeight: "700" }}>
                Giới Thiệu Về Cơ Sở Dạy Thêm 141 Nguyễn Thiện Kế
              </h3>
            </div>

            <p style={{ color: "var(--text-secondary)", lineHeight: "1.7", fontSize: "0.95rem", marginBottom: "1.5rem" }}>
              Tọa lạc tại địa chỉ sầm uất **141 Nguyễn Thiện Kế, Sơn Trà, TP. Đà Nẵng**, trung tâm là địa chỉ luyện thi và bồi dưỡng văn hóa hàng đầu dành cho học sinh từ **Khối 6 đến Khối 12**. Với phương châm *"Lấy học sinh làm trung tâm - Bám sát năng lực - Đạt điểm số tối đa"*, trung tâm cam kết mang lại hiệu quả vượt bậc cho từng học sinh.
            </p>

            {/* 4 Feature Cards */}
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))", gap: "1.25rem" }}>
              <div style={{ backgroundColor: "var(--bg-secondary)", padding: "1.25rem", borderRadius: "14px", border: "1px solid var(--border-color)" }}>
                <div style={{ width: "42px", height: "42px", borderRadius: "10px", backgroundColor: "rgba(13, 148, 136, 0.15)", display: "flex", alignItems: "center", justifyContent: "center", marginBottom: "0.85rem" }}>
                  <ShieldCheck size={24} color="var(--accent-primary)" />
                </div>
                <h4 style={{ fontSize: "1rem", fontWeight: "700", marginBottom: "0.4rem" }}>Đội Ngũ Giáo Viên</h4>
                <p style={{ fontSize: "0.85rem", color: "var(--text-muted)", lineHeight: "1.5" }}>
                  Giáo viên giàu kinh nghiệm sư phạm, tâm huyết, luôn theo dõi sát sao tình hình làm bài và tiếp thu của từng học sinh.
                </p>
              </div>

              <div style={{ backgroundColor: "var(--bg-secondary)", padding: "1.25rem", borderRadius: "14px", border: "1px solid var(--border-color)" }}>
                <div style={{ width: "42px", height: "42px", borderRadius: "10px", backgroundColor: "rgba(59, 130, 246, 0.15)", display: "flex", alignItems: "center", justifyContent: "center", marginBottom: "0.85rem" }}>
                  <Users size={24} color="var(--info)" />
                </div>
                <h4 style={{ fontSize: "1rem", fontWeight: "700", marginBottom: "0.4rem" }}>Sĩ Số Giới Hạn</h4>
                <p style={{ fontSize: "0.85rem", color: "var(--text-muted)", lineHeight: "1.5" }}>
                  Mỗi lớp chỉ từ 15 - 20 học sinh giúp giáo viên kèm cặp sát sao, phát hiện lỗ hổng kiến thức và bù đắp kịp thời.
                </p>
              </div>

              <div style={{ backgroundColor: "var(--bg-secondary)", padding: "1.25rem", borderRadius: "14px", border: "1px solid var(--border-color)" }}>
                <div style={{ width: "42px", height: "42px", borderRadius: "10px", backgroundColor: "rgba(16, 185, 129, 0.15)", display: "flex", alignItems: "center", justifyContent: "center", marginBottom: "0.85rem" }}>
                  <CheckCircle2 size={24} color="var(--success)" />
                </div>
                <h4 style={{ fontSize: "1rem", fontWeight: "700", marginBottom: "0.4rem" }}>Báo Cáo Trên Ứng Dụng</h4>
                <p style={{ fontSize: "0.85rem", color: "var(--text-muted)", lineHeight: "1.5" }}>
                  Kết nối 2 chiều qua Web & App Android: Điểm danh, điểm kiểm tra, học phí và nhận xét buổi học được gửi trực tiếp cho Phụ huynh.
                </p>
              </div>

              <div style={{ backgroundColor: "var(--bg-secondary)", padding: "1.25rem", borderRadius: "14px", border: "1px solid var(--border-color)" }}>
                <div style={{ width: "42px", height: "42px", borderRadius: "10px", backgroundColor: "rgba(245, 158, 11, 0.15)", display: "flex", alignItems: "center", justifyContent: "center", marginBottom: "0.85rem" }}>
                  <Sparkles size={24} color="var(--warning)" />
                </div>
                <h4 style={{ fontSize: "1rem", fontWeight: "700", marginBottom: "0.4rem" }}>Luyện Thi Chuyên & THPT</h4>
                <p style={{ fontSize: "0.85rem", color: "var(--text-muted)", lineHeight: "1.5" }}>
                  Bộ đề thi thử bám sát cấu trúc mới của Bộ GD&ĐT, tỉ lệ học sinh đỗ lớp 10 công lập & trường chuyên luôn nằm trong top đầu.
                </p>
              </div>
            </div>
          </div>

          {/* SECTION 2: HÌNH ẢNH CƠ SỞ VẬT CHẤT THỰC TẾ */}
          <div className="glass-panel" style={{ padding: "1.75rem" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.25rem", flexWrap: "wrap", gap: "0.75rem" }}>
              <div style={{ display: "flex", alignItems: "center", gap: "0.6rem" }}>
                <Building2 size={24} color="var(--accent-primary)" />
                <h3 style={{ fontFamily: "'Be Vietnam Pro', sans-serif", fontSize: "1.35rem", fontWeight: "700" }}>
                  Hình Ảnh Thật Cơ Sở Vật Chất 141 Nguyễn Thiện Kế
                </h3>
              </div>
              <span
                style={{
                  fontSize: "0.78rem",
                  backgroundColor: "rgba(13, 148, 136, 0.15)",
                  color: "var(--accent-primary)",
                  padding: "0.3rem 0.75rem",
                  borderRadius: "20px",
                  fontWeight: "700",
                  border: "1px solid rgba(13, 148, 136, 0.3)",
                }}
              >
                📸 7 Hình ảnh chụp thực tế tại Trung tâm
              </span>
            </div>

            {/* Photo Gallery Grid */}
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: "1.25rem" }}>
              {[
                {
                  src: "/images/center/Anhcoso.jpg",
                  title: "Mặt Tiền & Biển Hiệu Cơ Sở 141 Nguyễn Thiện Kế",
                  desc: "Cơ sở khang trang, sạch đẹp nằm ở vị trí trung tâm sầm uất Quận Sơn Trà.",
                  tag: "Mặt Tiền Cơ Sở",
                },
                {
                  src: "/images/center/H001.jpg",
                  title: "Phòng Học Máy Lạnh & Ánh Sáng Chống Cận",
                  desc: "Bàn ghế chuẩn học đường, hệ thống máy lạnh công suất lớn mát mẻ.",
                  tag: "Phòng Học Chuẩn",
                },
                {
                  src: "/images/center/H002.jpg",
                  title: "Giờ Học Bồi Dưỡng Kiến Thức Tương Tác Sôi Nổi",
                  desc: "Giáo viên hướng dẫn trực tiếp từng dạng bài, học sinh thoải mái hỏi đáp.",
                  tag: "Không Gian Học",
                },
                {
                  src: "/images/center/H003.jpg",
                  title: "Buổi Luyện Đề Thi Thử & Đánh Giá Năng Lực",
                  desc: "Rèn luyện kỹ năng làm bài kiểm tra bám sát cấu trúc đề thi mới nhất.",
                  tag: "Luyện Đề Kiểm Tra",
                },
                {
                  src: "/images/center/H005.jpg",
                  title: "Bảng Từ Chống Lóa & Thiết Bị Giảng Dạy Hiện Đại",
                  desc: "Trang bị đầy đủ dụng cụ hỗ trợ minh họa sinh động các môn Toán & KHTN.",
                  tag: "Thiết Bị Hiện Đại",
                },
                {
                  src: "/images/center/H006.jpg",
                  title: "Sĩ Số Lớp Học Giới Hạn Kèm Cặp Tận Tâm",
                  desc: "Lớp học từ 15-20 học sinh giúp thầy cô bám sát tiến độ từng em.",
                  tag: "Theo Sát Học Sinh",
                },
                {
                  src: "/images/center/H007.jpg",
                  title: "Môi Trường Học Tập Thân Thiện & Tích Cực",
                  desc: "Tạo động lực thi đua bứt phá điểm số và phát triển tư duy.",
                  tag: "Tuyên Dương Kịp Thời",
                },
              ].map((photo, idx) => (
                <div
                  key={idx}
                  onClick={() => setSelectedPhoto(photo)}
                  style={{
                    backgroundColor: "var(--bg-secondary)",
                    borderRadius: "14px",
                    border: "1px solid var(--border-color)",
                    overflow: "hidden",
                    cursor: "pointer",
                    transition: "transform 0.25s ease, box-shadow 0.25s ease",
                  }}
                  className="hover-card-zoom"
                >
                  <div style={{ height: "180px", overflow: "hidden", position: "relative" }}>
                    <img
                      src={photo.src}
                      alt={photo.title}
                      style={{
                        width: "100%",
                        height: "100%",
                        objectFit: "cover",
                        transition: "transform 0.4s ease",
                      }}
                    />
                    <span
                      style={{
                        position: "absolute",
                        top: "0.65rem",
                        left: "0.65rem",
                        backgroundColor: "rgba(15, 23, 42, 0.75)",
                        backdropFilter: "blur(4px)",
                        color: "#ffffff",
                        padding: "0.2rem 0.6rem",
                        borderRadius: "8px",
                        fontSize: "0.72rem",
                        fontWeight: "700",
                      }}
                    >
                      {photo.tag}
                    </span>
                  </div>

                  <div style={{ padding: "1rem" }}>
                    <h4 style={{ fontSize: "0.95rem", fontWeight: "700", marginBottom: "0.35rem", color: "var(--text-primary)", lineHeight: "1.4" }}>
                      {photo.title}
                    </h4>
                    <p style={{ fontSize: "0.82rem", color: "var(--text-muted)", lineHeight: "1.5" }}>
                      {photo.desc}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* SECTION 3: FORM ĐĂNG KÝ LỚP HỌC & LỊCH HỌC MONG MUỐN */}
          <div className="glass-panel" style={{ padding: "1.75rem", border: "2px solid var(--accent-primary)" }}>
            <div style={{ display: "flex", alignItems: "center", gap: "0.6rem", marginBottom: "0.5rem" }}>
              <Sparkles size={24} color="var(--accent-primary)" />
              <h3 style={{ fontSize: "1.35rem", fontWeight: "800" }}>
                Đăng Ký Lớp Học & Lịch Học Mong Muốn
              </h3>
            </div>
            <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem", marginBottom: "1.5rem" }}>
              Phụ huynh & Học sinh vui lòng điền thông tin bên dưới để được tư vấn xếp lớp và nhận lịch học phù hợp nhất!
            </p>

            {regSuccessMsg && (
              <div
                style={{
                  padding: "1rem 1.25rem",
                  backgroundColor: "rgba(16, 185, 129, 0.15)",
                  border: "1px solid var(--success)",
                  borderRadius: "var(--radius-md)",
                  color: "var(--success)",
                  fontWeight: "600",
                  marginBottom: "1.5rem",
                  display: "flex",
                  alignItems: "center",
                  gap: "0.5rem",
                }}
              >
                <CheckCircle2 size={20} />
                <span>{regSuccessMsg}</span>
              </div>
            )}

            <form onSubmit={handleRegisterSubmit} style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: "1.25rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                  Họ và tên học sinh *
                </label>
                <input
                  type="text"
                  required
                  placeholder="Ví dụ: Nguyễn Văn An"
                  value={regForm.ho_ten}
                  onChange={(e) => setRegForm({ ...regForm, ho_ten: e.target.value })}
                  style={{
                    width: "100%",
                    padding: "0.75rem",
                    borderRadius: "var(--radius-md)",
                    backgroundColor: "var(--bg-secondary)",
                    border: "1px solid var(--border-color)",
                    color: "var(--text-primary)",
                    outline: "none",
                  }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                  Khối học hiện tại *
                </label>
                <select
                  value={regForm.khoi}
                  onChange={(e) => setRegForm({ ...regForm, khoi: e.target.value })}
                  style={{
                    width: "100%",
                    padding: "0.75rem",
                    borderRadius: "var(--radius-md)",
                    backgroundColor: "var(--bg-secondary)",
                    border: "1px solid var(--border-color)",
                    color: "var(--text-primary)",
                    outline: "none",
                  }}
                >
                  <option value="Khối 6">Khối 6 (THCS)</option>
                  <option value="Khối 7">Khối 7 (THCS)</option>
                  <option value="Khối 8">Khối 8 (THCS)</option>
                  <option value="Khối 9">Khối 9 (Luyện thi vào 10)</option>
                  <option value="Khối 10">Khối 10 (THPT)</option>
                  <option value="Khối 11">Khối 11 (THPT)</option>
                  <option value="Khối 12">Khối 12 (Luyện thi THPT Quốc Gia)</option>
                </select>
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                  Số điện thoại Phụ huynh / Học sinh *
                </label>
                <input
                  type="tel"
                  required
                  placeholder="Ví dụ: 0905073175"
                  value={regForm.sdt}
                  onChange={(e) => setRegForm({ ...regForm, sdt: e.target.value })}
                  style={{
                    width: "100%",
                    padding: "0.75rem",
                    borderRadius: "var(--radius-md)",
                    backgroundColor: "var(--bg-secondary)",
                    border: "1px solid var(--border-color)",
                    color: "var(--text-primary)",
                    outline: "none",
                  }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                  Trường đang theo học
                </label>
                <input
                  type="text"
                  placeholder="Ví dụ: THCS Nguyễn Chi Phương"
                  value={regForm.truong}
                  onChange={(e) => setRegForm({ ...regForm, truong: e.target.value })}
                  style={{
                    width: "100%",
                    padding: "0.75rem",
                    borderRadius: "var(--radius-md)",
                    backgroundColor: "var(--bg-secondary)",
                    border: "1px solid var(--border-color)",
                    color: "var(--text-primary)",
                    outline: "none",
                  }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                  Môn học cần đăng ký bồi dưỡng
                </label>
                <input
                  type="text"
                  placeholder="Ví dụ: Toán, Tiếng Anh, Vật Lý..."
                  value={regForm.mon_hoc}
                  onChange={(e) => setRegForm({ ...regForm, mon_hoc: e.target.value })}
                  style={{
                    width: "100%",
                    padding: "0.75rem",
                    borderRadius: "var(--radius-md)",
                    backgroundColor: "var(--bg-secondary)",
                    border: "1px solid var(--border-color)",
                    color: "var(--text-primary)",
                    outline: "none",
                  }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                  Lịch học mong muốn
                </label>
                <input
                  type="text"
                  placeholder="Ví dụ: Ca tối T2-T4-T6 (17:30 - 19:00)"
                  value={regForm.lich_mong_muon}
                  onChange={(e) => setRegForm({ ...regForm, lich_mong_muon: e.target.value })}
                  style={{
                    width: "100%",
                    padding: "0.75rem",
                    borderRadius: "var(--radius-md)",
                    backgroundColor: "var(--bg-secondary)",
                    border: "1px solid var(--border-color)",
                    color: "var(--text-primary)",
                    outline: "none",
                  }}
                />
              </div>

              <div style={{ gridColumn: "1 / -1" }}>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                  Ghi chú / Yêu cầu thêm (Mục tiêu điểm số, phụ đạo thêm...)
                </label>
                <textarea
                  rows={3}
                  placeholder="Ví dụ: Con cần lấy lại gốc môn Toán và ôn thi vào lớp 10 Chuyên..."
                  value={regForm.ghi_chu}
                  onChange={(e) => setRegForm({ ...regForm, ghi_chu: e.target.value })}
                  style={{
                    width: "100%",
                    padding: "0.75rem",
                    borderRadius: "var(--radius-md)",
                    backgroundColor: "var(--bg-secondary)",
                    border: "1px solid var(--border-color)",
                    color: "var(--text-primary)",
                    outline: "none",
                    resize: "vertical",
                  }}
                />
              </div>

              <div style={{ gridColumn: "1 / -1", display: "flex", justifyContent: "flex-end" }}>
                <button
                  type="submit"
                  disabled={submittingReg}
                  className="btn-primary"
                  style={{
                    padding: "0.85rem 2rem",
                    fontSize: "1rem",
                    fontWeight: "700",
                    display: "flex",
                    alignItems: "center",
                    gap: "0.6rem",
                  }}
                >
                  <Send size={18} />
                  {submittingReg ? "Đang gửi hồ sơ..." : "GỬI ĐĂNG KÝ XẾP LỚP HỌC"}
                </button>
              </div>
            </form>
          </div>

          {/* SECTION 4: ĐÁNH GIÁ & NHẬN XÉT TỪ PHỤ HUYNH / HỌC SINH */}
          <div className="glass-panel" style={{ padding: "1.75rem" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.25rem", flexWrap: "wrap", gap: "0.75rem" }}>
              <div style={{ display: "flex", alignItems: "center", gap: "0.6rem" }}>
                <MessageSquare size={24} color="var(--accent-primary)" />
                <h3 style={{ fontSize: "1.35rem", fontWeight: "800" }}>
                  Đánh Giá & Nhận Xét Từ Phụ Huynh / Học Sinh
                </h3>
              </div>

              <div style={{ display: "flex", alignItems: "center", gap: "0.25rem", color: "var(--warning)" }}>
                {[...Array(5)].map((_, i) => (
                  <Star key={i} size={18} fill="var(--warning)" />
                ))}
                <span style={{ fontWeight: "800", color: "#ffffff", marginLeft: "0.5rem" }}>5.0 / 5.0</span>
              </div>
            </div>

            {/* Existing Review Cards */}
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))", gap: "1.25rem", marginBottom: "1.75rem" }}>
              {reviews.map((r, idx) => (
                <div
                  key={r.id || idx}
                  style={{
                    backgroundColor: "var(--bg-secondary)",
                    padding: "1.25rem",
                    borderRadius: "14px",
                    border: "1px solid var(--border-color)",
                    display: "flex",
                    flexDirection: "column",
                    justifyContent: "space-between",
                  }}
                >
                  <div>
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0.5rem" }}>
                      <span style={{ fontWeight: "700", color: "var(--accent-primary)", fontSize: "0.95rem" }}>{r.ten}</span>
                      <div style={{ display: "flex", gap: "2px", color: "var(--warning)" }}>
                        {[...Array(r.danh_gia || 5)].map((_, i) => (
                          <Star key={i} size={14} fill="var(--warning)" />
                        ))}
                      </div>
                    </div>
                    <p style={{ fontSize: "0.78rem", color: "var(--text-muted)", marginBottom: "0.75rem" }}>{r.vai_tro}</p>
                    <p style={{ fontSize: "0.88rem", color: "var(--text-primary)", lineHeight: "1.6", italic: "true" }}>
                      "{r.noi_dung}"
                    </p>
                  </div>
                  <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "0.75rem", textAlign: "right" }}>
                    {r.ngay}
                  </div>
                </div>
              ))}
            </div>

            {/* Write New Review Form */}
            <div style={{ backgroundColor: "var(--bg-primary)", padding: "1.25rem", borderRadius: "12px", border: "1px solid var(--border-color)" }}>
              <h4 style={{ fontSize: "1rem", fontWeight: "700", marginBottom: "0.75rem", display: "flex", alignItems: "center", gap: "0.4rem" }}>
                <Edit size={16} color="var(--accent-primary)" />
                Gửi Đánh Giá Của Bạn Về Trung Tâm
              </h4>

              {reviewMsg && (
                <div style={{ color: "var(--success)", fontWeight: "600", fontSize: "0.85rem", marginBottom: "0.75rem" }}>
                  ✓ {reviewMsg}
                </div>
              )}

              <form onSubmit={handleReviewSubmit} style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))", gap: "1rem" }}>
                <input
                  type="text"
                  required
                  placeholder="Họ tên của bạn (Ví dụ: Phụ huynh em An)"
                  value={newReview.ten}
                  onChange={(e) => setNewReview({ ...newReview, ten: e.target.value })}
                  style={{
                    padding: "0.65rem",
                    borderRadius: "8px",
                    backgroundColor: "var(--bg-secondary)",
                    border: "1px solid var(--border-color)",
                    color: "var(--text-primary)",
                    outline: "none",
                  }}
                />

                <input
                  type="text"
                  placeholder="Vai trò (Ví dụ: Phụ huynh Khối 9)"
                  value={newReview.vai_tro}
                  onChange={(e) => setNewReview({ ...newReview, vai_tro: e.target.value })}
                  style={{
                    padding: "0.65rem",
                    borderRadius: "8px",
                    backgroundColor: "var(--bg-secondary)",
                    border: "1px solid var(--border-color)",
                    color: "var(--text-primary)",
                    outline: "none",
                  }}
                />

                <div style={{ gridColumn: "1 / -1" }}>
                  <textarea
                    rows={2}
                    required
                    placeholder="Nhập nội dung nhận xét đánh giá chất lượng dạy & học..."
                    value={newReview.noi_dung}
                    onChange={(e) => setNewReview({ ...newReview, noi_dung: e.target.value })}
                    style={{
                      width: "100%",
                      padding: "0.65rem",
                      borderRadius: "8px",
                      backgroundColor: "var(--bg-secondary)",
                      border: "1px solid var(--border-color)",
                      color: "var(--text-primary)",
                      outline: "none",
                    }}
                  />
                </div>

                <div style={{ gridColumn: "1 / -1", display: "flex", justifyContent: "flex-end" }}>
                  <button type="submit" disabled={submittingReview} className="btn-secondary" style={{ padding: "0.6rem 1.25rem", fontWeight: "600" }}>
                    {submittingReview ? "Đang gửi..." : "Gửi Đánh Giá"}
                  </button>
                </div>
              </form>
            </div>
          </div>

          {/* SECTION 5: ĐỊA CHỈ, SĐT, EMAIL & CHỈ DẪN BẢN ĐỒ GOOGLE MAPS */}
          <div className="glass-panel" style={{ padding: "1.75rem" }}>
            <div style={{ display: "flex", alignItems: "center", gap: "0.6rem", marginBottom: "1.25rem" }}>
              <MapPin size={24} color="var(--accent-primary)" />
              <h3 style={{ fontSize: "1.35rem", fontWeight: "800" }}>
                Thông Tin Liên Hệ & Chỉ Dẫn Bản Đồ Google Maps
              </h3>
            </div>

            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))", gap: "1.5rem" }}>
              {/* Contact Info Detail List */}
              <div style={{ display: "flex", flexDirection: "column", gap: "1.2rem" }}>
                <div style={{ display: "flex", alignItems: "flex-start", gap: "0.85rem" }}>
                  <div style={{ width: "40px", height: "40px", borderRadius: "10px", backgroundColor: "rgba(13, 148, 136, 0.15)", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                    <MapPin size={20} color="var(--accent-primary)" />
                  </div>
                  <div>
                    <h4 style={{ fontSize: "0.95rem", fontWeight: "700" }}>Địa Chỉ Cơ Sở</h4>
                    <p style={{ fontSize: "0.9rem", color: "var(--text-secondary)", marginTop: "0.2rem" }}>
                      141 Nguyễn Thiện Kế, Phường An Hải Đông, Quận Sơn Trà, TP. Đà Nẵng
                    </p>
                  </div>
                </div>

                <div style={{ display: "flex", alignItems: "flex-start", gap: "0.85rem" }}>
                  <div style={{ width: "40px", height: "40px", borderRadius: "10px", backgroundColor: "rgba(16, 185, 129, 0.15)", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                    <Phone size={20} color="var(--success)" />
                  </div>
                  <div>
                    <h4 style={{ fontSize: "0.95rem", fontWeight: "700" }}>Số Điện Thoại / Zalo Tư Vấn</h4>
                    <p style={{ fontSize: "0.9rem", color: "var(--success)", fontWeight: "700", marginTop: "0.2rem" }}>
                      0905.073.175 - 0932.457.056
                    </p>
                  </div>
                </div>

                <div style={{ display: "flex", alignItems: "flex-start", gap: "0.85rem" }}>
                  <div style={{ width: "40px", height: "40px", borderRadius: "10px", backgroundColor: "rgba(59, 130, 246, 0.15)", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                    <Mail size={20} color="var(--info)" />
                  </div>
                  <div>
                    <h4 style={{ fontSize: "0.95rem", fontWeight: "700" }}>Email Liên Hệ</h4>
                    <p style={{ fontSize: "0.9rem", color: "var(--text-secondary)", marginTop: "0.2rem" }}>
                      bavuong@moet.edu.vn
                    </p>
                  </div>
                </div>

                <div style={{ display: "flex", alignItems: "flex-start", gap: "0.85rem" }}>
                  <div style={{ width: "40px", height: "40px", borderRadius: "10px", backgroundColor: "rgba(245, 158, 11, 0.15)", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                    <Clock size={20} color="var(--warning)" />
                  </div>
                  <div>
                    <h4 style={{ fontSize: "0.95rem", fontWeight: "700" }}>Thời Gian Giảng Dạy</h4>
                    <p style={{ fontSize: "0.9rem", color: "var(--text-secondary)", marginTop: "0.2rem" }}>
                      Từ 07:30 - 21:30 (Tất cả các ngày từ Thứ Hai đến Chủ Nhật)
                    </p>
                  </div>
                </div>

                <a
                  href="https://maps.google.com/?q=141+Nguyen+Thien+Ke+Son+Tra+Da+Nang"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="btn-primary"
                  style={{
                    display: "inline-flex",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: "0.5rem",
                    padding: "0.85rem 1.5rem",
                    marginTop: "0.5rem",
                    textDecoration: "none",
                  }}
                >
                  <ExternalLink size={18} />
                  MỞ BẢN ĐỒ GOOGLE MAPS CHỈ ĐƯỜNG TỚI 141 NGUYỄN THIỆN KẾ
                </a>
              </div>

              {/* Embedded Google Maps Frame */}
              <div style={{ borderRadius: "14px", overflow: "hidden", border: "1px solid var(--border-color)", height: "300px" }}>
                <iframe
                  title="Google Maps Location"
                  src="https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3834.023456789!2d108.2345678!3d16.0612345!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x314219d123456789%3A0x123456789abcdef!2zMTQxIE5ndXnhu4VuIFRoaeG7h24gS-G6vywgQW4gSG basketIMSQw7RuZywgU8ahbiBUcsOgLCDEkOG6oSBOxINuZyA1NTAwMDAsIFZpZXRuYW0!5e0!3m2!1svi!2s!4v1700000000000!5m2!1svi!2s"
                  width="100%"
                  height="100%"
                  style={{ border: 0 }}
                  allowFullScreen=""
                  loading="lazy"
                  referrerPolicy="no-referrer-when-downgrade"
                />
              </div>
            </div>
          </div>
        </div>
      )}

      {/* 4. MANAGEMENT DASHBOARD TAB CONTENT */}
      {activeTab === "dashboard" && (
        <div>
          {/* KPI Cards Grid */}
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
              gap: "1.25rem",
              marginBottom: "2rem",
            }}
          >
            <div className="glass-card">
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div>
                  <p style={{ color: "var(--text-muted)", fontSize: "0.85rem", fontWeight: "600" }}>
                    TỔNG HỌC SINH ĐANG HỌC
                  </p>
                  <h3 style={{ fontSize: "1.8rem", fontWeight: "800", margin: "0.3rem 0" }}>
                    {loading ? "..." : stats.totalStudents}
                  </h3>
                  <span className="badge badge-success">
                    <TrendingUp size={12} /> Realtime Cloud
                  </span>
                </div>
                <div
                  style={{
                    width: "48px",
                    height: "48px",
                    borderRadius: "14px",
                    backgroundColor: "rgba(13, 148, 136, 0.15)",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                  }}
                >
                  <Users size={26} color="var(--accent-primary)" />
                </div>
              </div>
            </div>

            <div className="glass-card">
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div>
                  <p style={{ color: "var(--text-muted)", fontSize: "0.85rem", fontWeight: "600" }}>
                    TỔNG LỚP HỌC
                  </p>
                  <h3 style={{ fontSize: "1.8rem", fontWeight: "800", margin: "0.3rem 0" }}>
                    {loading ? "..." : stats.totalClasses}
                  </h3>
                  <span className="badge badge-info">Đang hoạt động</span>
                </div>
                <div
                  style={{
                    width: "48px",
                    height: "48px",
                    borderRadius: "14px",
                    backgroundColor: "rgba(59, 130, 246, 0.15)",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                  }}
                >
                  <GraduationCap size={26} color="var(--info)" />
                </div>
              </div>
            </div>

            {userRole === "ADMIN" && (
              <>
                <div className="glass-card">
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                    <div>
                      <p style={{ color: "var(--text-muted)", fontSize: "0.85rem", fontWeight: "600" }}>
                        HỌC PHÍ ĐÃ THU
                      </p>
                      <h3 style={{ fontSize: "1.5rem", fontWeight: "800", margin: "0.3rem 0", color: "var(--success)" }}>
                        {loading ? "..." : formatCurrency(stats.totalCollected)}
                      </h3>
                      <span className="badge badge-success">Đã thu ngân</span>
                    </div>
                    <div
                      style={{
                        width: "48px",
                        height: "48px",
                        borderRadius: "14px",
                        backgroundColor: "rgba(16, 185, 129, 0.15)",
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                      }}
                    >
                      <CreditCard size={26} color="var(--success)" />
                    </div>
                  </div>
                </div>

                <div className="glass-card">
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                    <div>
                      <p style={{ color: "var(--text-muted)", fontSize: "0.85rem", fontWeight: "600" }}>
                        CÒN NỢ HỌC PHÍ
                      </p>
                      <h3 style={{ fontSize: "1.5rem", fontWeight: "800", margin: "0.3rem 0", color: "var(--danger)" }}>
                        {loading ? "..." : formatCurrency(stats.totalDebt)}
                      </h3>
                      <span className="badge badge-warning">
                        <AlertCircle size={12} /> Cần nhắc nợ
                      </span>
                    </div>
                    <div
                      style={{
                        width: "48px",
                        height: "48px",
                        borderRadius: "14px",
                        backgroundColor: "rgba(239, 68, 68, 0.15)",
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                      }}
                    >
                      <AlertCircle size={26} color="var(--danger)" />
                    </div>
                  </div>
                </div>
              </>
            )}
          </div>

          {/* Analytics & Today Schedule Grid */}
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(350px, 1fr))", gap: "1.5rem", marginBottom: "1.5rem" }}>
            {/* Revenue Doughnut Chart - Only for Admin */}
            {userRole === "ADMIN" && (
              <div className="glass-panel" style={{ padding: "1.5rem" }}>
                <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1rem" }}>
                  Tỷ Lệ Thu Học Phí
                </h3>
                <div style={{ maxHeight: "260px", display: "flex", justifyContent: "center" }}>
                  <Doughnut data={chartData} options={{ maintainAspectRatio: false }} />
                </div>
              </div>
            )}

            {/* Grade Bar Chart */}
            <div className="glass-panel" style={{ padding: "1.5rem" }}>
              <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1rem" }}>
                Phân Bố Lớp Học Theo Khối
              </h3>
              <div style={{ maxHeight: "260px" }}>
                <Bar data={gradeChartData} options={{ maintainAspectRatio: false }} />
              </div>
            </div>
          </div>

          {/* Registrations List Node (Incoming Web Signups) */}
          {registrations.length > 0 && (
            <div className="glass-panel" style={{ padding: "1.5rem", marginBottom: "1.5rem" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                  <Sparkles size={20} color="var(--accent-primary)" />
                  <h3 style={{ fontSize: "1.1rem", fontWeight: "700" }}>Danh Sách Đăng Ký Học Mới Từ Web</h3>
                </div>
                <span className="badge badge-info">{registrations.length} Hồ sơ mới</span>
              </div>

              <div style={{ overflowX: "auto" }}>
                <table className="custom-table" style={{ width: "100%", fontSize: "0.88rem" }}>
                  <thead>
                    <tr>
                      <th>Mã Đăng Ký</th>
                      <th>Họ và Tên HS</th>
                      <th>Khối Học</th>
                      <th>SĐT Liên Hệ</th>
                      <th>Môn Đăng Ký</th>
                      <th>Lịch Mong Muốn</th>
                      <th>Ngày Đăng Ký</th>
                    </tr>
                  </thead>
                  <tbody>
                    {registrations.map((reg) => (
                      <tr key={reg.id}>
                        <td><span style={{ fontWeight: "700", color: "var(--accent-primary)" }}>{reg.id}</span></td>
                        <td><strong>{reg.ho_ten}</strong></td>
                        <td>{reg.khoi}</td>
                        <td><span style={{ color: "var(--success)", fontWeight: "600" }}>{reg.sdt}</span></td>
                        <td>{reg.mon_hoc}</td>
                        <td>{reg.lich_mong_muon}</td>
                        <td>{reg.ngay_dang_ky}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* Today Schedule Section */}
          <div className="glass-panel" style={{ padding: "1.5rem" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem" }}>
              <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                <Clock size={20} color="var(--accent-primary)" />
                <h3 style={{ fontSize: "1.1rem", fontWeight: "700" }}>Lịch Dạy Hôm Nay</h3>
              </div>
              <span className="badge badge-info">{todaySchedule.length} Ca dạy</span>
            </div>

            {todaySchedule.length === 0 ? (
              <div style={{ textAlign: "center", padding: "2rem 0", color: "var(--text-muted)" }}>
                Không có ca học nào được lên lịch cho hôm nay.
              </div>
            ) : (
              <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))", gap: "1rem" }}>
                {todaySchedule.map((s, idx) => (
                  <div
                    key={idx}
                    style={{
                      padding: "1rem",
                      borderRadius: "var(--radius-md)",
                      backgroundColor: "var(--bg-secondary)",
                      border: "1px solid var(--border-color)",
                    }}
                  >
                    <h4 style={{ fontSize: "1rem", fontWeight: "700", color: "var(--accent-primary)" }}>
                      {s.tenLop || `Lớp học #${s.id_lop}`}
                    </h4>
                    <p style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginTop: "0.25rem" }}>
                      Thời gian: {s.gioBatDau || s.gio_bat_dau} - {s.gioKetThuc || s.gio_ket_thuc}
                    </p>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* FULL-SCREEN PHOTO LIGHTBOX MODAL */}
      {selectedPhoto && (
        <div
          onClick={() => setSelectedPhoto(null)}
          style={{
            position: "fixed",
            inset: 0,
            backgroundColor: "rgba(0, 0, 0, 0.88)",
            backdropFilter: "blur(8px)",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            zIndex: 200,
            padding: "1.5rem",
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              maxHeight: "90vh",
              maxWidth: "850px",
              backgroundColor: "var(--bg-card)",
              borderRadius: "16px",
              overflow: "hidden",
              border: "1px solid var(--border-color)",
              boxShadow: "0 20px 60px rgba(0,0,0,0.5)",
              display: "flex",
              flexDirection: "column",
            }}
          >
            <div style={{ position: "relative", backgroundColor: "#000" }}>
              <img
                src={selectedPhoto.src}
                alt={selectedPhoto.title}
                style={{
                  width: "100%",
                  maxHeight: "65vh",
                  objectFit: "contain",
                  display: "block",
                }}
              />
              <button
                type="button"
                onClick={() => setSelectedPhoto(null)}
                style={{
                  position: "absolute",
                  top: "1rem",
                  right: "1rem",
                  backgroundColor: "rgba(0,0,0,0.7)",
                  color: "#ffffff",
                  border: "none",
                  borderRadius: "50%",
                  width: "36px",
                  height: "36px",
                  fontSize: "1.2rem",
                  cursor: "pointer",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                ✕
              </button>
            </div>

            <div style={{ padding: "1.25rem", backgroundColor: "var(--bg-secondary)" }}>
              <span
                style={{
                  fontSize: "0.75rem",
                  fontWeight: "700",
                  backgroundColor: "var(--accent-primary)",
                  color: "#ffffff",
                  padding: "0.2rem 0.6rem",
                  borderRadius: "6px",
                  display: "inline-block",
                  marginBottom: "0.4rem",
                }}
              >
                {selectedPhoto.tag}
              </span>
              <h3 style={{ fontSize: "1.15rem", fontWeight: "800", color: "var(--text-primary)", marginBottom: "0.35rem" }}>
                {selectedPhoto.title}
              </h3>
              <p style={{ fontSize: "0.88rem", color: "var(--text-secondary)", lineHeight: "1.5" }}>
                {selectedPhoto.desc}
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
