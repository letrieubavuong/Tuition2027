"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { db, ref, onValue, set, push, remove } from "@/lib/firebase";
import Link from "next/link";
import {
  ArrowLeft,
  User,
  Phone,
  School,
  FileText,
  Calendar,
  CreditCard,
  Award,
  GraduationCap,
  MessageCircle,
  Plus,
  Trash2,
  PauseCircle,
  PlayCircle,
  CheckCircle2,
  XCircle,
  Clock
} from "lucide-react";

export default function StudentDetailContainer() {
  const params = useParams();
  const studentId = params.id;

  const [student, setStudent] = useState(null);
  const [allClasses, setAllClasses] = useState([]);
  const [enrolledRecords, setEnrolledRecords] = useState([]);
  const [attendanceLogs, setAttendanceLogs] = useState([]);
  const [paymentLogs, setPaymentLogs] = useState([]);
  const [loading, setLoading] = useState(true);

  // Modal State for Assigning to Class
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [selectedClassToAssign, setSelectedClassToAssign] = useState("");

  useEffect(() => {
    if (!studentId) return;

    // 1. Fetch Student Info
    const hsRef = ref(db, `hoc_sinh/${studentId}`);
    const unsubHs = onValue(hsRef, (snapshot) => {
      const val = snapshot.val();
      setStudent(val);
      setLoading(false);
    });

    // 2. Fetch All Classes
    const lopRef = ref(db, "lop_hoc");
    const unsubLop = onValue(lopRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = Array.isArray(val)
          ? val.map((item, idx) => (item ? { ...item, _key: item.id || idx } : null)).filter(Boolean)
          : Object.entries(val).map(([k, v]) => ({ ...v, _key: k }));
        setAllClasses(list);
      }
    });

    // 3. Fetch Enrolled Class Connections (lop_hoc_sinh)
    const lhsRef = ref(db, "lop_hoc_sinh");
    const unsubLhs = onValue(lhsRef, (snapshotLhs) => {
      const lhsVal = snapshotLhs.val();
      if (lhsVal) {
        let lhsList = [];
        if (Array.isArray(lhsVal)) {
          lhsList = lhsVal
            .map((item, idx) => (item ? { ...item, _key: item.id || idx } : null))
            .filter(Boolean);
        } else {
          lhsList = Object.entries(lhsVal).map(([k, v]) => ({ ...v, _key: k }));
        }

        const myRecords = lhsList.filter(
          (lhs) => String(lhs.id_hoc_sinh || lhs.hoc_sinh_id) === String(studentId)
        );
        setEnrolledRecords(myRecords);
      } else {
        setEnrolledRecords([]);
      }
    });

    // 4. Fetch Attendance History
    const ddRef = ref(db, "diem_danh");
    const unsubDd = onValue(ddRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        const myLogs = [];
        list.forEach((dd) => {
          if (dd.danh_sach && dd.danh_sach[studentId]) {
            myLogs.push({
              ngay: dd.ngay,
              lop_id: dd.lop_id,
              trang_thai: dd.danh_sach[studentId],
            });
          }
        });
        setAttendanceLogs(myLogs);
      }
    });

    // 5. Fetch Payment History
    const ttRef = ref(db, "thanh_toan");
    const unsubTt = onValue(ttRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        const myLogs = list.filter(
          (tt) => String(tt.id_hoc_sinh ?? tt.hoc_sinh_id) === String(studentId)
        );

        // Deduplicate payment records by unique month + class
        const payMap = new Map();
        myLogs.forEach((p) => {
          const monthKey = p.thang ?? p.month ?? p.thang_nam ?? "UNKNOWN";
          const classKey = p.id_lop ?? p.lop_id ?? "ALL";
          const uniqueKey = `${monthKey}_${classKey}`;
          if (!payMap.has(uniqueKey)) {
            payMap.set(uniqueKey, p);
          } else {
            const existing = payMap.get(uniqueKey);
            const newTime = p.updated_at ? new Date(p.updated_at).getTime() : 0;
            const existingTime = existing.updated_at ? new Date(existing.updated_at).getTime() : 0;
            if (newTime >= existingTime) payMap.set(uniqueKey, p);
          }
        });

        setPaymentLogs(Array.from(payMap.values()));
      }
    });

    return () => {
      unsubHs();
      unsubLop();
      unsubLhs();
      unsubDd();
      unsubTt();
    };
  }, [studentId]);

  // Clean phone number for Zalo
  const phone = student?.sdt_phu_huynh || student?.sdt || "";
  const cleanPhone = phone.replace(/[^0-9]/g, "");

  const handleOpenZalo = () => {
    if (!cleanPhone) {
      alert("Học sinh này chưa có số điện thoại phụ huynh!");
      return;
    }
    // Mở trực tiếp phần mềm Zalo PC trên máy tính (zalo.exe)
    window.location.href = `zalo://chat?phone=${cleanPhone}`;
    setTimeout(() => {
      window.open(`https://zalo.me/${cleanPhone}`, "_blank");
    }, 600);
  };

  // Assign Student to a new Class
  const handleAssignToClass = async (e) => {
    e.preventDefault();
    if (!selectedClassToAssign) return;

    try {
      const newId = Date.now();
      const itemRef = ref(db, `lop_hoc_sinh/${newId}`);
      await set(itemRef, {
        id: newId,
        id_hoc_sinh: Number(studentId) || studentId,
        id_lop: Number(selectedClassToAssign) || selectedClassToAssign,
        ngay_tham_gia: new Date().toISOString().split("T")[0],
        trang_thai: "DANG_HOC",
      });
      setShowAssignModal(false);
      setSelectedClassToAssign("");
    } catch (err) {
      alert("Lỗi khi xếp lớp cho học sinh: " + err.message);
    }
  };

  // Change Student Class Status (DANG_HOC, TAM_NGHI, DA_NGHI)
  const handleChangeClassStatus = async (recordKey, newStatus) => {
    try {
      const itemRef = ref(db, `lop_hoc_sinh/${recordKey}/trang_thai`);
      await set(itemRef, newStatus);
    } catch (err) {
      alert("Lỗi cập nhật trạng thái lớp: " + err.message);
    }
  };

  // Remove from Class
  const handleRemoveFromClass = async (recordKey) => {
    if (confirm("Bạn có chắc chắn muốn xóa học sinh khỏi lớp này?")) {
      try {
        await remove(ref(db, `lop_hoc_sinh/${recordKey}`));
      } catch (err) {
        alert("Lỗi xóa khỏi lớp: " + err.message);
      }
    }
  };

  // Get student school name safely
  const schoolName = student?.truong_dang_hoc || student?.truong || student?.ten_truong || student?.truong_hoc || "";

  // Helper to generate monthly payment history from student join date to current month
  const getFullMonthlyPaymentHistory = () => {
    const dates = [];
    if (student?.ngay_tham_gia && typeof student.ngay_tham_gia === "string") dates.push(student.ngay_tham_gia);
    if (student?.created_at && typeof student.created_at === "string") dates.push(student.created_at);
    if (Array.isArray(enrolledRecords)) {
      enrolledRecords.forEach((lhs) => {
        if (lhs && lhs.ngay_tham_gia && typeof lhs.ngay_tham_gia === "string") dates.push(lhs.ngay_tham_gia);
      });
    }
    if (Array.isArray(paymentLogs)) {
      paymentLogs.forEach((p) => {
        const m = p?.thang || p?.month || p?.thang_nam;
        if (m && typeof m === "string" && m.length >= 7) dates.push(`${m}-01`);
      });
    }

    const now = new Date();
    const curYear = now.getFullYear();
    const curMonth = now.getMonth() + 1;

    let startYear = curYear;
    let startMonth = 1;

    if (dates.length > 0) {
      const validDateStrs = dates
        .map((d) => String(d).trim())
        .filter((d) => /^\d{4}/.test(d));

      if (validDateStrs.length > 0) {
        validDateStrs.sort();
        const earliest = validDateStrs[0];
        const parts = earliest.split(/[-/]/);
        if (parts.length >= 2) {
          const y = parseInt(parts[0], 10);
          const m = parseInt(parts[1], 10);
          if (!isNaN(y) && !isNaN(m) && y >= 2020 && y <= curYear && m >= 1 && m <= 12) {
            startYear = y;
            startMonth = m;
          }
        }
      }
    }

    // Safety guard: Limit history to at most 2 years (24 months) back
    if (startYear < curYear - 2) {
      startYear = curYear - 2;
    }

    const monthList = [];
    let y = startYear;
    let m = startMonth;
    let guard = 0;

    while ((y < curYear || (y === curYear && m <= curMonth)) && guard < 60) {
      monthList.push(`${y}-${String(m).padStart(2, '0')}`);
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
      guard++;
    }

    const reversedMonths = monthList.reverse();

    return reversedMonths.map((mStr) => {
      const existing = (paymentLogs || []).find(
        (p) => (p?.thang || p?.month || p?.thang_nam) === mStr
      );
      if (existing) {
        return existing;
      }
      return {
        thang: mStr,
        so_tien_da_dong: 0,
        tong_thanh_toan: 0,
        isMissing: true,
      };
    });
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

      {/* Student Profile Card Header */}
      <div className="glass-panel" style={{ padding: "1.75rem", marginBottom: "1.5rem" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", flexWrap: "wrap", gap: "1.25rem" }}>
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

            <div>
              <h2 style={{ fontSize: "1.6rem", fontWeight: "800" }}>{student.ten}</h2>
              <div style={{ display: "flex", gap: "1.25rem", flexWrap: "wrap", marginTop: "0.4rem", color: "var(--text-secondary)", fontSize: "0.9rem" }}>
                {phone && (
                  <span style={{ display: "flex", alignItems: "center", gap: "0.35rem" }}>
                    <Phone size={15} color="var(--accent-primary)" /> SĐT: {phone}
                  </span>
                )}
                {schoolName && (
                  <span style={{ display: "flex", alignItems: "center", gap: "0.35rem" }}>
                    <School size={15} color="var(--info)" /> Trường: {schoolName}
                  </span>
                )}
              </div>
            </div>
          </div>

          {/* Quick Action Buttons: Zalo, Call, Assign Class */}
          <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}>
            {cleanPhone && (
              <button
                onClick={handleOpenZalo}
                style={{
                  backgroundColor: "#0068ff",
                  color: "#ffffff",
                  border: "none",
                  padding: "0.6rem 1rem",
                  borderRadius: "var(--radius-md)",
                  fontWeight: "600",
                  fontSize: "0.85rem",
                  cursor: "pointer",
                  display: "flex",
                  alignItems: "center",
                  gap: "0.4rem",
                  boxShadow: "0 4px 12px rgba(0, 104, 255, 0.3)",
                }}
              >
                <MessageCircle size={16} /> Nhắn Zalo Phụ Huynh
              </button>
            )}

            {phone && (
              <a
                href={`tel:${phone}`}
                className="btn-secondary"
                style={{ display: "flex", alignItems: "center", gap: "0.4rem", textDecoration: "none" }}
              >
                <Phone size={15} /> Gọi Điện
              </a>
            )}

            <button
              onClick={() => setShowAssignModal(true)}
              className="btn-primary"
              style={{ display: "flex", alignItems: "center", gap: "0.4rem" }}
            >
              <Plus size={16} /> Xếp Vào Lớp Học
            </button>
          </div>
        </div>

        {student.ghi_chu && (
          <div style={{ marginTop: "1rem", paddingTop: "0.75rem", borderTop: "1px solid var(--border-color)", fontSize: "0.85rem", color: "var(--text-secondary)" }}>
            <strong>Ghi chú:</strong> {student.ghi_chu}
          </div>
        )}
      </div>

      {/* Enrolled Classes & Status Section */}
      <div className="glass-panel" style={{ padding: "1.5rem", marginBottom: "1.5rem" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem" }}>
          <h3 style={{ fontSize: "1.1rem", fontWeight: "700", display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <GraduationCap size={18} color="var(--accent-primary)" /> Danh Sách Lớp Theo Học ({enrolledRecords.length})
          </h3>
        </div>

        {enrolledRecords.length === 0 ? (
          <p style={{ color: "var(--text-muted)", fontSize: "0.9rem" }}>Học sinh chưa xếp vào lớp học nào. Nhấp "Xếp Vào Lớp Học" ở trên để gán lớp.</p>
        ) : (
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(300px, 1fr))", gap: "1rem" }}>
            {enrolledRecords.map((rec) => {
              const lopId = rec.id_lop || rec.lop_id;
              const lopInfo = allClasses.find(
                (c) => String(c._key) === String(lopId) || String(c.id) === String(lopId)
              );
              const status = rec.trang_thai || "DANG_HOC";

              return (
                <div
                  key={rec._key}
                  style={{
                    padding: "1rem",
                    borderRadius: "var(--radius-md)",
                    backgroundColor: "var(--bg-secondary)",
                    border: "1px solid var(--border-color)",
                    display: "flex",
                    flexDirection: "column",
                    justifyContent: "space-between",
                    gap: "0.75rem",
                  }}
                >
                  <div>
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0.5rem" }}>
                      <span className="badge badge-info">
                        Khối {lopInfo?.khoi || "Chung"}
                      </span>
                      {status === "DANG_HOC" ? (
                        <span className="badge badge-success" style={{ display: "flex", alignItems: "center", gap: "0.25rem" }}>
                          <CheckCircle2 size={12} /> Đang học
                        </span>
                      ) : status === "TAM_NGHI" ? (
                        <span className="badge badge-warning" style={{ display: "flex", alignItems: "center", gap: "0.25rem" }}>
                          <PauseCircle size={12} /> Tạm nghỉ
                        </span>
                      ) : (
                        <span className="badge" style={{ backgroundColor: "rgba(239, 68, 68, 0.2)", color: "var(--danger)" }}>
                          Đã nghỉ hẳn
                        </span>
                      )}
                    </div>

                    <h4 style={{ fontWeight: "700", fontSize: "1.05rem" }}>
                      {lopInfo ? (lopInfo.ten_lop || lopInfo.ten) : "Lớp #" + lopId}
                    </h4>
                    <p style={{ fontSize: "0.8rem", color: "var(--text-secondary)", marginTop: "0.25rem" }}>
                      Học phí: {formatCurrency(lopInfo?.hoc_phi_buoi || lopInfo?.hoc_phi)} / buổi
                    </p>
                  </div>

                  {/* Status Change Buttons */}
                  <div style={{ display: "flex", gap: "0.4rem", flexWrap: "wrap", paddingTop: "0.5rem", borderTop: "1px dashed var(--border-color)" }}>
                    {status !== "TAM_NGHI" && (
                      <button
                        onClick={() => handleChangeClassStatus(rec._key, "TAM_NGHI")}
                        className="btn-secondary"
                        style={{ padding: "0.3rem 0.6rem", fontSize: "0.75rem", color: "var(--warning)" }}
                      >
                        <PauseCircle size={13} /> Cho Tạm Nghỉ
                      </button>
                    )}

                    {status !== "DANG_HOC" && (
                      <button
                        onClick={() => handleChangeClassStatus(rec._key, "DANG_HOC")}
                        className="btn-secondary"
                        style={{ padding: "0.3rem 0.6rem", fontSize: "0.75rem", color: "var(--success)" }}
                      >
                        <PlayCircle size={13} /> Học Lại
                      </button>
                    )}

                    <button
                      onClick={() => handleRemoveFromClass(rec._key)}
                      className="btn-secondary"
                      style={{ padding: "0.3rem 0.6rem", fontSize: "0.75rem", color: "var(--danger)", marginLeft: "auto" }}
                    >
                      <Trash2 size={13} /> Xóa Lớp
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Payment & Attendance Logs Grid */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))", gap: "1.5rem" }}>
        {/* Payment History */}
        <div className="glass-panel" style={{ padding: "1.5rem" }}>
          <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <CreditCard size={18} color="var(--success)" /> Lịch Sử Đóng Học Phí
          </h3>
          {(() => {
            const historyList = getFullMonthlyPaymentHistory();
            if (historyList.length === 0) {
              return <p style={{ color: "var(--text-muted)", fontSize: "0.9rem" }}>Chưa có lịch sử học phí nào.</p>;
            }

            return (
              <div style={{ display: "flex", flexDirection: "column", gap: "0.75rem" }}>
                {historyList.map((p, idx) => {
                  const daDong = Number(p.so_tien_da_dong ?? p.so_tien ?? 0);
                  const tong = Number(p.tong_thanh_toan ?? 0);
                  const isPaid = (tong > 0 && daDong >= tong) || (!p.isMissing && tong === 0 && daDong > 0);
                  const conNo = Math.max(0, tong - daDong);

                  return (
                    <div
                      key={idx}
                      style={{
                        padding: "0.75rem 1rem",
                        borderRadius: "var(--radius-md)",
                        backgroundColor: "var(--bg-secondary)",
                        border: "1px solid var(--border-color)",
                        display: "flex",
                        justifyContent: "space-between",
                        alignItems: "center",
                      }}
                    >
                      <div>
                        <div style={{ fontWeight: "700" }}>Tháng {p.thang || p.thang_nam || "--"}</div>
                        <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>
                          {p.isMissing ? (
                            "Tháng học kể từ ngày tham gia"
                          ) : (
                            <>
                              Đã đóng: <strong>{formatCurrency(daDong)}</strong> {tong > 0 ? `/ ${formatCurrency(tong)}` : ""}
                            </>
                          )}
                        </div>
                      </div>
                      {isPaid ? (
                        <span className="badge badge-success">Đã hoàn tất</span>
                      ) : p.isMissing ? (
                        <span className="badge badge-danger">Chưa đóng học phí</span>
                      ) : (
                        <span className="badge badge-warning">Còn nợ {formatCurrency(conNo)}</span>
                      )}
                    </div>
                  );
                })}
              </div>
            );
          })()}
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
                    <div style={{ fontWeight: "600", fontSize: "0.9rem" }}>{dd.ngay}</div>
                    <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>Buổi học lớp #{dd.lop_id}</div>
                  </div>
                  <span className={dd.trang_thai === "CoMat" ? "badge badge-success" : dd.trang_thai === "Muon" ? "badge badge-warning" : "badge badge-danger"}>
                    {dd.trang_thai === "CoMat" ? "Có mặt" : dd.trang_thai === "Muon" ? "Đi muộn" : "Vắng"}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Modal Dialog Assign Student to Class */}
      {showAssignModal && (
        <div
          style={{
            position: "fixed",
            inset: 0,
            backgroundColor: "rgba(0, 0, 0, 0.6)",
            backdropFilter: "blur(4px)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            zIndex: 100,
            padding: "1rem",
          }}
        >
          <div className="glass-panel" style={{ width: "100%", maxWidth: "450px", padding: "1.75rem", backgroundColor: "var(--bg-secondary)" }}>
            <h3 style={{ fontSize: "1.25rem", fontWeight: "700", marginBottom: "1.25rem" }}>
              Xếp Học Sinh Vào Lớp Học
            </h3>

            <form onSubmit={handleAssignToClass} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Chọn Lớp Học *
                </label>
                <select
                  required
                  value={selectedClassToAssign}
                  onChange={(e) => setSelectedClassToAssign(e.target.value)}
                  className="input-control"
                  style={{ width: "100%" }}
                >
                  <option value="">-- Chọn Lớp --</option>
                  {allClasses.map((c) => (
                    <option key={c._key} value={c._key}>
                      {c.ten_lop || c.ten} {c.mon ? `(${c.mon})` : ""} - Khối {c.khoi || "--"}
                    </option>
                  ))}
                </select>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "1rem" }}>
                <button type="button" onClick={() => setShowAssignModal(false)} className="btn-secondary">
                  Hủy
                </button>
                <button type="submit" className="btn-primary">
                  Xác Nhận Xếp Lớp
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
