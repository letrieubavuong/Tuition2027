"use client";

import { useEffect, useState } from "react";
import { db, ref, onValue } from "@/lib/firebase";
import {
  BarChart3,
  TrendingUp,
  CreditCard,
  Users,
  GraduationCap,
  CalendarCheck,
  Award
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

export default function ThongKePage() {
  const [students, setStudents] = useState([]);
  const [classes, setClasses] = useState([]);
  const [payments, setPayments] = useState([]);
  const [attendance, setAttendance] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const hsRef = ref(db, "hoc_sinh");
    const unsubHs = onValue(hsRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = Array.isArray(val)
          ? val.filter(Boolean)
          : Object.values(val);
        setStudents(list);
      }
    });

    const lopRef = ref(db, "lop_hoc");
    const unsubLop = onValue(lopRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = Array.isArray(val)
          ? val.filter(Boolean)
          : Object.values(val);
        setClasses(list);
      }
    });

    const payRef = ref(db, "thanh_toan");
    const unsubPay = onValue(payRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = Array.isArray(val)
          ? val.filter(Boolean)
          : Object.values(val);
        setPayments(list);
      }
    });

    const ddRef = ref(db, "diem_danh");
    const unsubDd = onValue(ddRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = Array.isArray(val)
          ? val.filter(Boolean)
          : Object.values(val);
        setAttendance(list);
      }
      setLoading(false);
    });

    return () => {
      unsubHs();
      unsubLop();
      unsubPay();
      unsubDd();
    };
  }, []);

  // Compute Revenue Stats
  const totalRevenueCollected = payments.reduce(
    (acc, cur) => acc + (Number(cur.so_tien_da_dong) || Number(cur.so_tien) || Number(cur.soTien) || 0),
    0
  );

  // Class Distribution
  const classNames = classes.map((c) => c.ten_lop || c.ten || "Lớp");
  const studentCountsPerClass = classes.map((c) => Number(c.si_so) || 0);

  const classChartData = {
    labels: classNames.length > 0 ? classNames : ["Lớp Toán 10", "Lớp Lý 11", "Lớp Hóa 12"],
    datasets: [
      {
        label: "Số lượng Học Sinh",
        data: studentCountsPerClass.length > 0 ? studentCountsPerClass : [12, 18, 15],
        backgroundColor: "rgba(13, 148, 136, 0.7)",
        borderColor: "#0d9488",
        borderWidth: 1,
        borderRadius: 8,
      },
    ],
  };

  // Attendance Status Distribution
  let coMatCount = 0;
  let vangCount = 0;
  let muonCount = 0;

  attendance.forEach((record) => {
    if (record.danh_sach) {
      Object.values(record.danh_sach).forEach((st) => {
        if (st === "CoMat") coMatCount++;
        else if (st === "VangCoPhep" || st === "VangKhongPhep") vangCount++;
        else if (st === "Muon") muonCount++;
      });
    }
  });

  const totalAtt = coMatCount + vangCount + muonCount;

  const attendanceChartData = {
    labels: ["Có Mặt", "Vắng Mặt", "Đi Muộn"],
    datasets: [
      {
        data: totalAtt > 0 ? [coMatCount, vangCount, muonCount] : [85, 10, 5],
        backgroundColor: [
          "rgba(16, 185, 129, 0.8)",
          "rgba(239, 68, 68, 0.8)",
          "rgba(249, 115, 22, 0.8)",
        ],
        borderWidth: 0,
      },
    ],
  };

  return (
    <div>
      {/* Header */}
      <div style={{ marginBottom: "1.75rem" }}>
        <h2 style={{ fontSize: "1.75rem", fontWeight: "700" }}>Báo Cáo & Thống Kê</h2>
        <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem" }}>
          Phân tích doanh thu, sỉ số các lớp và tình hình đi học của học sinh
        </p>
      </div>

      {/* Overview Stat Cards */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
          gap: "1.25rem",
          marginBottom: "1.75rem",
        }}
      >
        <div className="glass-panel" style={{ padding: "1.25rem" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0.75rem" }}>
            <span style={{ fontSize: "0.85rem", color: "var(--text-secondary)" }}>Tổng Doanh Thu Đã Thu</span>
            <CreditCard size={20} color="var(--success)" />
          </div>
          <div style={{ fontSize: "1.5rem", fontWeight: "700", color: "var(--success)" }}>
            {totalRevenueCollected.toLocaleString("vi-VN")} đ
          </div>
          <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "0.35rem" }}>
            Cập nhật từ lịch sử thanh toán Realtime
          </div>
        </div>

        <div className="glass-panel" style={{ padding: "1.25rem" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0.75rem" }}>
            <span style={{ fontSize: "0.85rem", color: "var(--text-secondary)" }}>Tổng Học Sinh</span>
            <Users size={20} color="var(--accent-primary)" />
          </div>
          <div style={{ fontSize: "1.5rem", fontWeight: "700" }}>{students.length} Học sinh</div>
          <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "0.35rem" }}>
            Đang hoạt động trong hệ thống
          </div>
        </div>

        <div className="glass-panel" style={{ padding: "1.25rem" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0.75rem" }}>
            <span style={{ fontSize: "0.85rem", color: "var(--text-secondary)" }}>Tổng Số Lớp Học</span>
            <GraduationCap size={20} color="#8b5cf6" />
          </div>
          <div style={{ fontSize: "1.5rem", fontWeight: "700" }}>{classes.length} Lớp</div>
          <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "0.35rem" }}>
            Các lớp đang mở giảng dạy
          </div>
        </div>

        <div className="glass-panel" style={{ padding: "1.25rem" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0.75rem" }}>
            <span style={{ fontSize: "0.85rem", color: "var(--text-secondary)" }}>Tỷ Lệ Chuyên Cần</span>
            <CalendarCheck size={20} color="var(--warning)" />
          </div>
          <div style={{ fontSize: "1.5rem", fontWeight: "700" }}>
            {totalAtt > 0 ? `${Math.round((coMatCount / totalAtt) * 100)}%` : "95%"}
          </div>
          <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "0.35rem" }}>
            Tỷ lệ học sinh đi học đầy đủ
          </div>
        </div>
      </div>

      {/* Charts Grid */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(350px, 1fr))",
          gap: "1.5rem",
        }}
      >
        {/* Class Size Bar Chart */}
        <div className="glass-panel" style={{ padding: "1.5rem" }}>
          <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1.25rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <BarChart3 size={20} color="var(--accent-primary)" />
            Phân Bổ Học Sinh Theo Lớp
          </h3>
          <div style={{ height: "260px" }}>
            <Bar
              data={classChartData}
              options={{
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                  legend: { display: false },
                },
                scales: {
                  y: { beginAtZero: true, grid: { color: "rgba(255,255,255,0.05)" } },
                  x: { grid: { display: false } },
                },
              }}
            />
          </div>
        </div>

        {/* Attendance Doughnut Chart */}
        <div className="glass-panel" style={{ padding: "1.5rem" }}>
          <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1.25rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <TrendingUp size={20} color="var(--success)" />
            Tình Hình Đi Học Tổng Quan
          </h3>
          <div style={{ height: "260px", display: "flex", justifyContent: "center", alignItems: "center" }}>
            <Doughnut
              data={attendanceChartData}
              options={{
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                  legend: { position: "bottom" },
                },
              }}
            />
          </div>
        </div>
      </div>
    </div>
  );
}
