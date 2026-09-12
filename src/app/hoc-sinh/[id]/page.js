"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { db, ref, onValue } from "@/lib/firebase";
import Link from "next/link";
import { ArrowLeft, User, Phone, School, FileText, Calendar, CreditCard, Award, GraduationCap } from "lucide-react";

export default function StudentDetailContainer() {
  const params = useParams();
  const studentId = params.id;

  const [student, setStudent] = useState(null);
  const [enrolledClasses, setEnrolledClasses] = useState([]);
  const [attendanceLogs, setAttendanceLogs] = useState([]);
  const [paymentLogs, setPaymentLogs] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!studentId) return;

    // 1. Fetch Student Info
    const hsRef = ref(db, `hoc_sinh/${studentId}`);
    const unsubHs = onValue(hsRef, (snapshot) => {
      const val = snapshot.val();
      setStudent(val);
      setLoading(false);
    });

    // 2. Fetch Enrolled Classes
    const lhsRef = ref(db, "lop_hoc_sinh");
    const lopRef = ref(db, "lop");
    const unsubLhs = onValue(lhsRef, (snapshotLhs) => {
      const lhsVal = snapshotLhs.val();
      if (lhsVal) {
        const lhsList = Array.isArray(lhsVal) ? lhsVal.filter(Boolean) : Object.values(lhsVal);
        const myLhs = lhsList.filter((lhs) => String(lhs.id_hoc_sinh) === String(studentId));

        onValue(lopRef, (snapshotLop) => {
          const lopVal = snapshotLop.val();
          if (lopVal) {
            const lopList = Array.isArray(lopVal) ? lopVal.filter(Boolean) : Object.values(lopVal);
            const myClasses = myLhs
              .map((lhs) => lopList.find((l) => String(l.id) === String(lhs.id_lop)))
              .filter(Boolean);
            setEnrolledClasses(myClasses);
          }
        });
      }
    });

    // 3. Fetch Attendance History
    const ddRef = ref(db, "diem_danh");
    const unsubDd = onValue(ddRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        const myLogs = list.filter((dd) => String(dd.id_hoc_sinh) === String(studentId));
        setAttendanceLogs(myLogs);
      }
    });

    // 4. Fetch Payment History
    const ttRef = ref(db, "thanh_toan");
    const unsubTt = onValue(ttRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        const myLogs = list.filter((tt) => String(tt.id_hoc_sinh) === String(studentId));
        setPaymentLogs(myLogs);
      }
    });

    return () => {
      unsubHs();
      unsubLhs();
      unsubDd();
      unsubTt();
    };
  }, [studentId]);

  const formatCurrency = (num) => {
    return new Intl.NumberFormat("vi-VN", { style: "currency", currency: "VND" }).format(num || 0);
  };

  if (loading) {
    return <div style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>Đang nạp hồ sơ học sinh...</div>;
  }

  if (!student) {
    return (
      <div>
        <Link href="/hoc-sinh" className="btn-secondary" style={{ marginBottom: "1rem" }}>
          <ArrowLeft size={16} /> Quay lại danh sách học sinh
        </Link>
        <div className="glass-panel" style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
          Không tìm thấy hồ sơ học sinh này.
        </div>
      </div>
    );
  }

  return (
    <div>
      <Link href="/hoc-sinh" className="btn-secondary" style={{ marginBottom: "1.25rem" }}>
        <ArrowLeft size={16} /> Quay lại danh sách học sinh
      </Link>

      {/* Student Profile Card */}
      <div className="glass-panel" style={{ padding: "1.75rem", marginBottom: "1.5rem" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "1.25rem", flexWrap: "wrap" }}>
          <div
            style={{
              width: "64px",
              height: "64px",
              borderRadius: "50%",
              background: "var(--accent-gradient)",
              color: "#ffffff",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: "1.75rem",
              fontWeight: "800",
              boxShadow: "0 6px 20px var(--accent-glow)",
            }}
          >
            {student.ten ? student.ten.charAt(0).toUpperCase() : "H"}
          </div>

          <div style={{ flex: 1 }}>
            <h2 style={{ fontSize: "1.6rem", fontWeight: "800" }}>{student.ten}</h2>
            <div style={{ display: "flex", gap: "1.25rem", flexWrap: "wrap", marginTop: "0.4rem", color: "var(--text-secondary)", fontSize: "0.9rem" }}>
              {(student.sdt_phu_huynh || student.sdt) && (
                <span style={{ display: "flex", alignItems: "center", gap: "0.35rem" }}>
                  <Phone size={15} color="var(--accent-primary)" /> Phụ huynh: {student.sdt_phu_huynh || student.sdt}
                </span>
              )}
              {student.truong && (
                <span style={{ display: "flex", alignItems: "center", gap: "0.35rem" }}>
                  <School size={15} color="var(--info)" /> Trường: {student.truong}
                </span>
              )}
            </div>
          </div>
        </div>

        {student.ghi_chu && (
          <div style={{ marginTop: "1rem", paddingTop: "0.75rem", borderTop: "1px solid var(--border-color)", fontSize: "0.85rem", color: "var(--text-secondary)" }}>
            <strong>Ghi chú:</strong> {student.ghi_chu}
          </div>
        )}
      </div>

      {/* Enrolled Classes Section */}
      <div className="glass-panel" style={{ padding: "1.5rem", marginBottom: "1.5rem" }}>
        <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
          <GraduationCap size={18} color="var(--accent-primary)" /> Lớp Học Đang Theo Học ({enrolledClasses.length})
        </h3>
        {enrolledClasses.length === 0 ? (
          <p style={{ color: "var(--text-muted)", fontSize: "0.9rem" }}>Học sinh chưa xếp vào lớp học nào.</p>
        ) : (
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(260px, 1fr))", gap: "1rem" }}>
            {enrolledClasses.map((c) => (
              <div key={c.id} style={{ padding: "1rem", borderRadius: "var(--radius-md)", backgroundColor: "var(--bg-secondary)", border: "1px solid var(--border-color)" }}>
                <span className="badge badge-info" style={{ marginBottom: "0.35rem" }}>Khối {c.khoi}</span>
                <h4 style={{ fontWeight: "700", fontSize: "1.05rem" }}>{c.ten}</h4>
                <p style={{ fontSize: "0.8rem", color: "var(--text-secondary)", marginTop: "0.25rem" }}>
                  Học phí: {formatCurrency(c.hoc_phi_buoi)} / buổi
                </p>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Payment & Attendance History Grid */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))", gap: "1.5rem" }}>
        {/* Payment History */}
        <div className="glass-panel" style={{ padding: "1.5rem" }}>
          <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <CreditCard size={18} color="var(--success)" /> Lịch Sử Đóng Học Phí
          </h3>
          {paymentLogs.length === 0 ? (
            <p style={{ color: "var(--text-muted)", fontSize: "0.9rem" }}>Chưa có lịch sử học phí nào.</p>
          ) : (
            <div style={{ display: "flex", flexDirection: "column", gap: "0.75rem" }}>
              {paymentLogs.map((p, idx) => (
                <div key={idx} style={{ padding: "0.75rem 1rem", borderRadius: "var(--radius-md)", backgroundColor: "var(--bg-secondary)", border: "1px solid var(--border-color)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <div>
                    <div style={{ fontWeight: "700" }}>Tháng {p.thang}</div>
                    <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>Đã đóng: {formatCurrency(p.so_tien_da_dong)}</div>
                  </div>
                  <div style={{ textAlign: "right" }}>
                    <div style={{ fontWeight: "700", color: p.so_tien_da_dong >= p.tong_thanh_toan ? "var(--success)" : "var(--danger)" }}>
                      {p.so_tien_da_dong >= p.tong_thanh_toan ? "Đã xong" : `Nợ ${formatCurrency(p.tong_thanh_toan - p.so_tien_da_dong)}`}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Attendance History */}
        <div className="glass-panel" style={{ padding: "1.5rem" }}>
          <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <Calendar size={18} color="var(--info)" /> Nhật Ký Điểm Danh
          </h3>
          {attendanceLogs.length === 0 ? (
            <p style={{ color: "var(--text-muted)", fontSize: "0.9rem" }}>Chưa có nhật ký điểm danh.</p>
          ) : (
            <div style={{ display: "flex", flexDirection: "column", gap: "0.75rem" }}>
              {attendanceLogs.map((dd, idx) => (
                <div key={idx} style={{ padding: "0.75rem 1rem", borderRadius: "var(--radius-md)", backgroundColor: "var(--bg-secondary)", border: "1px solid var(--border-color)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <div>
                    <div style={{ fontWeight: "600", fontSize: "0.9rem" }}>{dd.gio_diem_danh || "Buổi học"}</div>
                    <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>{dd.ghi_chu || "Đã điểm danh"}</div>
                  </div>
                  <span className={dd.co_mat !== false ? "badge badge-success" : "badge badge-warning"}>
                    {dd.co_mat !== false ? "Có mặt" : "Vắng"}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
