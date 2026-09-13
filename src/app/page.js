"use client";

import { useEffect, useState } from "react";
import { db, ref, onValue } from "@/lib/firebase";
import {
  Users,
  GraduationCap,
  Calendar,
  CreditCard,
  TrendingUp,
  AlertCircle,
  Clock,
  ArrowUpRight
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

export default function Dashboard() {
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

  useEffect(() => {
    // Synchronize Students
    const hsRef = ref(db, "hoc_sinh");
    const lopRef = ref(db, "lop");
    const thanhToanRef = ref(db, "thanh_toan");
    const lichHocRef = ref(db, "lich_hoc");

    const unsubHs = onValue(hsRef, (snapshot) => {
      const val = snapshot.val();
      let count = 0;
      if (val) {
        const list = Array.isArray(val)
          ? val.filter((item) => item !== null)
          : Object.values(val);

        count = list.filter((s) => {
          if (!s) return false;
          const status = String(s.trang_thai || s.status || s.trangThai || "").toUpperCase();
          if (status === "DA_NGHI" || status === "NGHI_HOC" || s.da_nghi === 1 || s.da_nghi === true) {
            return false;
          }
          return true;
        }).length;
      }
      setStats((prev) => ({ ...prev, totalStudents: count }));
    });

    const unsubLop = onValue(lopRef, (snapshot) => {
      const val = snapshot.val();
      let count = 0;
      const grades = {};

      if (val) {
        const classList = Array.isArray(val)
          ? val.filter(Boolean)
          : Object.values(val);
        count = classList.length;

        classList.forEach((c) => {
          const k = c.khoi ? `Khối ${c.khoi}` : "Khác";
          grades[k] = (grades[k] || 0) + 1;
        });
      }
      setGradeDistribution(grades);
      setStats((prev) => ({ ...prev, totalClasses: count }));
    });

    const unsubThanhToan = onValue(thanhToanRef, (snapshot) => {
      const val = snapshot.val();
      let collected = 0;
      let debt = 0;

      if (val) {
        const records = Array.isArray(val)
          ? val.filter(Boolean)
          : Object.values(val);

        records.forEach((r) => {
          const daDong = Number(r.so_tien_da_dong) || 0;
          const tong = Number(r.tong_thanh_toan) || 0;
          collected += daDong;
          if (tong > daDong) {
            debt += tong - daDong;
          }
        });
      }

      setStats((prev) => ({
        ...prev,
        totalCollected: collected,
        totalDebt: debt,
      }));
      setLoading(false);
    });

    const unsubLichHoc = onValue(lichHocRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        const todayWeekday = new Date().getDay() + 1; // JS 0=Sun -> 1
        const filtered = list.filter((lh) => Number(lh.thuTrongTuan) === todayWeekday);
        setTodaySchedule(filtered);
        setStats((prev) => ({ ...prev, todaySessions: filtered.length }));
      }
    });

    return () => {
      unsubHs();
      unsubLop();
      unsubThanhToan();
      unsubLichHoc();
    };
  }, []);

  const formatCurrency = (num) => {
    return new Intl.NumberFormat("vi-VN", {
      style: "currency",
      currency: "VND",
    }).format(num);
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
      {/* Page Title Header */}
      <div style={{ marginBottom: "2rem" }}>
        <h2 style={{ fontSize: "1.75rem", fontWeight: "700", marginBottom: "0.5rem" }}>
          Tổng Quan Dashboard
        </h2>
        <p style={{ color: "var(--text-secondary)", fontSize: "0.95rem" }}>
          Thống kê dữ liệu học sinh & học phí theo thời gian thực từ Cloud Firebase
        </p>
      </div>

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
                TỔNG HỌC SINH
              </p>
              <h3 style={{ fontSize: "1.8rem", fontWeight: "800", margin: "0.3rem 0" }}>
                {loading ? "..." : stats.totalStudents}
              </h3>
              <span className="badge badge-success">
                <TrendingUp size={12} /> Realtime
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
      </div>

      {/* Analytics & Today Schedule Grid */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(350px, 1fr))", gap: "1.5rem" }}>
        {/* Revenue Doughnut Chart */}
        <div className="glass-panel" style={{ padding: "1.5rem" }}>
          <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1rem" }}>
            Tỷ Lệ Thu Học Phí
          </h3>
          <div style={{ maxHeight: "260px", display: "flex", justifyContent: "center" }}>
            <Doughnut data={chartData} options={{ maintainAspectRatio: false }} />
          </div>
        </div>

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

      {/* Today Schedule Section */}
      <div className="glass-panel" style={{ padding: "1.5rem", marginTop: "1.5rem" }}>
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
                  Thời gian: {s.gioBatDau} - {s.gioKetThuc}
                </p>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
