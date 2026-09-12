"use client";

import { useEffect, useState } from "react";
import { db, ref, onValue, set } from "@/lib/firebase";
import {
  CalendarCheck,
  CheckCircle,
  XCircle,
  Clock,
  AlertCircle,
  Save,
  Users,
  Award,
  BookOpen,
  Check
} from "lucide-react";

export default function DiemDanhPage() {
  const [classes, setClasses] = useState([]);
  const [students, setStudents] = useState([]);
  const [classStudents, setClassStudents] = useState([]);
  const [selectedClassId, setSelectedClassId] = useState("");
  const [attendanceDate, setAttendanceDate] = useState(
    new Date().toISOString().split("T")[0]
  );
  const [attendanceMap, setAttendanceMap] = useState({});
  const [ratingsMap, setRatingsMap] = useState({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [successMsg, setSuccessMsg] = useState("");

  // Load Classes and Students
  useEffect(() => {
    const classRef = ref(db, "lop_hoc");
    const unsubClasses = onValue(classRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = [];
        if (Array.isArray(val)) {
          list = val.map((item, idx) => (item ? { ...item, _key: item.id || idx } : null)).filter(Boolean);
        } else {
          list = Object.entries(val).map(([k, v]) => ({ ...v, _key: k }));
        }
        setClasses(list);
        if (list.length > 0 && !selectedClassId) {
          setSelectedClassId(list[0]._key);
        }
      }
    });

    const hsRef = ref(db, "hoc_sinh");
    const unsubHs = onValue(hsRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = [];
        if (Array.isArray(val)) {
          list = val.map((item, idx) => (item ? { ...item, _key: item.id || idx } : null)).filter(Boolean);
        } else {
          list = Object.entries(val).map(([k, v]) => ({ ...v, _key: k }));
        }
        setStudents(list);
      }
      setLoading(false);
    });

    const lopHsRef = ref(db, "lop_hoc_sinh");
    const unsubLopHs = onValue(lopHsRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = [];
        if (Array.isArray(val)) {
          list = val.filter(Boolean);
        } else {
          list = Object.values(val);
        }
        setClassStudents(list);
      }
    });

    return () => {
      unsubClasses();
      unsubHs();
      unsubLopHs();
    };
  }, []);

  // Filter students by selected class
  const targetStudentIds = classStudents
    .filter((cs) => String(cs.lop_id || cs.id_lop) === String(selectedClassId))
    .map((cs) => String(cs.hoc_sinh_id || cs.id_hoc_sinh));

  const filteredStudents = students.filter(
    (s) => targetStudentIds.includes(String(s.id)) || targetStudentIds.includes(String(s._key))
  );

  // Load attendance record for selected class and date
  useEffect(() => {
    if (!selectedClassId || !attendanceDate) return;

    const recordKey = `dd_${selectedClassId}_${attendanceDate.replace(/-/g, "")}`;
    const ddRef = ref(db, `diem_danh/${recordKey}`);
    const unsub = onValue(ddRef, (snapshot) => {
      const val = snapshot.val();
      if (val && val.danh_sach) {
        setAttendanceMap(val.danh_sach);
      } else {
        // Default all to CoMat
        const initMap = {};
        filteredStudents.forEach((s) => {
          const sid = s.id || s._key;
          initMap[sid] = "CoMat";
        });
        setAttendanceMap(initMap);
      }
    });

    return () => unsub();
  }, [selectedClassId, attendanceDate, classStudents, students]);

  const handleStatusChange = (studentId, status) => {
    setAttendanceMap((prev) => ({
      ...prev,
      [studentId]: status,
    }));
  };

  const handleRatingChange = (studentId, field, value) => {
    setRatingsMap((prev) => ({
      ...prev,
      [studentId]: {
        ...(prev[studentId] || {}),
        [field]: value,
      },
    }));
  };

  const handleSaveAttendance = async () => {
    if (!selectedClassId || !attendanceDate) return;
    setSaving(true);
    setSuccessMsg("");

    try {
      const recordKey = `dd_${selectedClassId}_${attendanceDate.replace(/-/g, "")}`;
      
      // Save Attendance
      await set(ref(db, `diem_danh/${recordKey}`), {
        lop_id: selectedClassId,
        ngay: attendanceDate,
        danh_sach: attendanceMap,
        updated_at: new Date().toISOString(),
      });

      // Save Detailed Ratings if filled
      if (Object.keys(ratingsMap).length > 0) {
        await set(ref(db, `danh_gia_buoi_hoc/${recordKey}`), {
          lop_id: selectedClassId,
          ngay: attendanceDate,
          danh_gia: ratingsMap,
          updated_at: new Date().toISOString(),
        });
      }

      setSuccessMsg("Đã lưu điểm danh & đánh giá thành công vào Cloud Firebase!");
      setTimeout(() => setSuccessMsg(""), 4000);
    } catch (err) {
      alert("Lỗi khi lưu điểm danh: " + err.message);
    } finally {
      setSaving(false);
    }
  };

  const currentClass = classes.find((c) => String(c._key) === String(selectedClassId));

  const stats = {
    total: filteredStudents.length,
    coMat: Object.values(attendanceMap).filter((s) => s === "CoMat").length,
    vangPhep: Object.values(attendanceMap).filter((s) => s === "VangCoPhep").length,
    vangKhongPhep: Object.values(attendanceMap).filter((s) => s === "VangKhongPhep").length,
    muon: Object.values(attendanceMap).filter((s) => s === "Muon").length,
  };

  return (
    <div>
      {/* Header */}
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          flexWrap: "wrap",
          gap: "1rem",
          marginBottom: "1.75rem",
        }}
      >
        <div>
          <h2 style={{ fontSize: "1.75rem", fontWeight: "700" }}>Điểm Danh Buổi Học</h2>
          <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem" }}>
            Ghi nhận chuyên cần, thái độ học tập và điểm thưởng theo buổi
          </p>
        </div>
        <button
          onClick={handleSaveAttendance}
          disabled={saving || filteredStudents.length === 0}
          className="btn-primary"
          style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}
        >
          <Save size={18} />
          {saving ? "Đang Lưu Cloud..." : "Lưu Điểm Danh"}
        </button>
      </div>

      {successMsg && (
        <div
          style={{
            padding: "1rem 1.25rem",
            backgroundColor: "rgba(16, 185, 129, 0.15)",
            border: "1px solid var(--success)",
            borderRadius: "var(--radius-md)",
            color: "var(--success)",
            marginBottom: "1.5rem",
            display: "flex",
            alignItems: "center",
            gap: "0.5rem",
          }}
        >
          <CheckCircle size={20} />
          <span style={{ fontWeight: "600" }}>{successMsg}</span>
        </div>
      )}

      {/* Control Panel: Select Class & Date */}
      <div className="glass-panel" style={{ padding: "1.25rem", marginBottom: "1.5rem" }}>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))", gap: "1.25rem" }}>
          <div>
            <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
              Chọn Lớp Học
            </label>
            <select
              value={selectedClassId}
              onChange={(e) => setSelectedClassId(e.target.value)}
              className="input-control"
              style={{ width: "100%" }}
            >
              {classes.map((c) => (
                <option key={c._key} value={c._key}>
                  {c.ten_lop || c.ten} {c.mon ? `(${c.mon})` : ""} - Sỉ số: {c.si_so || 0}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
              Chọn Ngày Điểm Danh
            </label>
            <input
              type="date"
              value={attendanceDate}
              onChange={(e) => setAttendanceDate(e.target.value)}
              className="input-control"
              style={{ width: "100%" }}
            />
          </div>
        </div>
      </div>

      {/* Stats Summary Bar */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(160px, 1fr))",
          gap: "1rem",
          marginBottom: "1.5rem",
        }}
      >
        <div className="glass-panel" style={{ padding: "1rem", textAlign: "center" }}>
          <div style={{ fontSize: "0.8rem", color: "var(--text-muted)", marginBottom: "0.25rem" }}>Sỉ số lớp</div>
          <div style={{ fontSize: "1.5rem", fontWeight: "700" }}>{stats.total} HS</div>
        </div>
        <div className="glass-panel" style={{ padding: "1rem", textAlign: "center", borderColor: "rgba(16, 185, 129, 0.3)" }}>
          <div style={{ fontSize: "0.8rem", color: "var(--success)", marginBottom: "0.25rem" }}>Có mặt</div>
          <div style={{ fontSize: "1.5rem", fontWeight: "700", color: "var(--success)" }}>{stats.coMat}</div>
        </div>
        <div className="glass-panel" style={{ padding: "1rem", textAlign: "center", borderColor: "rgba(245, 158, 11, 0.3)" }}>
          <div style={{ fontSize: "0.8rem", color: "var(--warning)", marginBottom: "0.25rem" }}>Vắng phép</div>
          <div style={{ fontSize: "1.5rem", fontWeight: "700", color: "var(--warning)" }}>{stats.vangPhep}</div>
        </div>
        <div className="glass-panel" style={{ padding: "1rem", textAlign: "center", borderColor: "rgba(239, 68, 68, 0.3)" }}>
          <div style={{ fontSize: "0.8rem", color: "var(--danger)", marginBottom: "0.25rem" }}>Vắng không phép</div>
          <div style={{ fontSize: "1.5rem", fontWeight: "700", color: "var(--danger)" }}>{stats.vangKhongPhep}</div>
        </div>
        <div className="glass-panel" style={{ padding: "1rem", textAlign: "center", borderColor: "rgba(249, 115, 22, 0.3)" }}>
          <div style={{ fontSize: "0.8rem", color: "#f97316", marginBottom: "0.25rem" }}>Đi muộn</div>
          <div style={{ fontSize: "1.5rem", fontWeight: "700", color: "#f97316" }}>{stats.muon}</div>
        </div>
      </div>

      {/* Roster & Attendance Marking */}
      <div className="glass-panel" style={{ padding: "1.5rem" }}>
        <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1.25rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
          <Users size={20} color="var(--accent-primary)" />
          Danh Sách Điểm Danh & Nhận Xét ({currentClass?.ten_lop || "Lớp"})
        </h3>

        {loading ? (
          <div style={{ padding: "2rem", textAlign: "center", color: "var(--text-muted)" }}>
            Đang tải danh sách học sinh...
          </div>
        ) : filteredStudents.length === 0 ? (
          <div style={{ padding: "2rem", textAlign: "center", color: "var(--text-muted)" }}>
            Chưa có học sinh nào được phân vào lớp này.
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
            {filteredStudents.map((s, idx) => {
              const sid = s.id || s._key;
              const status = attendanceMap[sid] || "CoMat";
              const rating = ratingsMap[sid] || {};

              return (
                <div
                  key={sid}
                  style={{
                    padding: "1rem 1.25rem",
                    borderRadius: "var(--radius-md)",
                    backgroundColor: "var(--bg-secondary)",
                    border: "1px solid var(--border-color)",
                    display: "flex",
                    flexDirection: "column",
                    gap: "1rem",
                  }}
                >
                  <div
                    style={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                      flexWrap: "wrap",
                      gap: "1rem",
                    }}
                  >
                    <div style={{ display: "flex", alignItems: "center", gap: "0.75rem" }}>
                      <span
                        style={{
                          width: "28px",
                          height: "28px",
                          borderRadius: "50%",
                          backgroundColor: "var(--bg-card)",
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                          fontWeight: "700",
                          fontSize: "0.8rem",
                          color: "var(--text-secondary)",
                        }}
                      >
                        {idx + 1}
                      </span>
                      <div>
                        <div style={{ fontWeight: "700", fontSize: "1rem" }}>{s.ten}</div>
                        <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>
                          SĐT: {s.sdt_phu_huynh || s.sdt || "--"}
                        </div>
                      </div>
                    </div>

                    {/* Status Toggle Buttons */}
                    <div style={{ display: "flex", gap: "0.4rem", flexWrap: "wrap" }}>
                      <button
                        type="button"
                        onClick={() => handleStatusChange(sid, "CoMat")}
                        style={{
                          padding: "0.4rem 0.75rem",
                          borderRadius: "var(--radius-md)",
                          fontSize: "0.85rem",
                          fontWeight: "600",
                          cursor: "pointer",
                          border: "none",
                          backgroundColor: status === "CoMat" ? "var(--success)" : "var(--bg-card)",
                          color: status === "CoMat" ? "#ffffff" : "var(--text-secondary)",
                          display: "flex",
                          alignItems: "center",
                          gap: "0.35rem",
                          transition: "var(--transition)",
                        }}
                      >
                        <CheckCircle size={14} /> Có Mặt
                      </button>

                      <button
                        type="button"
                        onClick={() => handleStatusChange(sid, "VangCoPhep")}
                        style={{
                          padding: "0.4rem 0.75rem",
                          borderRadius: "var(--radius-md)",
                          fontSize: "0.85rem",
                          fontWeight: "600",
                          cursor: "pointer",
                          border: "none",
                          backgroundColor: status === "VangCoPhep" ? "var(--warning)" : "var(--bg-card)",
                          color: status === "VangCoPhep" ? "#ffffff" : "var(--text-secondary)",
                          display: "flex",
                          alignItems: "center",
                          gap: "0.35rem",
                          transition: "var(--transition)",
                        }}
                      >
                        <Clock size={14} /> Vắng Có Phép
                      </button>

                      <button
                        type="button"
                        onClick={() => handleStatusChange(sid, "VangKhongPhep")}
                        style={{
                          padding: "0.4rem 0.75rem",
                          borderRadius: "var(--radius-md)",
                          fontSize: "0.85rem",
                          fontWeight: "600",
                          cursor: "pointer",
                          border: "none",
                          backgroundColor: status === "VangKhongPhep" ? "var(--danger)" : "var(--bg-card)",
                          color: status === "VangKhongPhep" ? "#ffffff" : "var(--text-secondary)",
                          display: "flex",
                          alignItems: "center",
                          gap: "0.35rem",
                          transition: "var(--transition)",
                        }}
                      >
                        <XCircle size={14} /> Vắng KP
                      </button>

                      <button
                        type="button"
                        onClick={() => handleStatusChange(sid, "Muon")}
                        style={{
                          padding: "0.4rem 0.75rem",
                          borderRadius: "var(--radius-md)",
                          fontSize: "0.85rem",
                          fontWeight: "600",
                          cursor: "pointer",
                          border: "none",
                          backgroundColor: status === "Muon" ? "#f97316" : "var(--bg-card)",
                          color: status === "Muon" ? "#ffffff" : "var(--text-secondary)",
                          display: "flex",
                          alignItems: "center",
                          gap: "0.35rem",
                          transition: "var(--transition)",
                        }}
                      >
                        <AlertCircle size={14} /> Đi Muộn
                      </button>
                    </div>
                  </div>

                  {/* Optional Rating / Comments */}
                  <div
                    style={{
                      display: "grid",
                      gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))",
                      gap: "0.75rem",
                      paddingTop: "0.75rem",
                      borderTop: "1px dashed var(--border-color)",
                    }}
                  >
                    <div>
                      <input
                        type="text"
                        placeholder="Nhận xét bài tập / thái độ..."
                        value={rating.nhan_xet || ""}
                        onChange={(e) => handleRatingChange(sid, "nhan_xet", e.target.value)}
                        className="input-control"
                        style={{ width: "100%", fontSize: "0.85rem" }}
                      />
                    </div>
                    <div>
                      <input
                        type="number"
                        placeholder="Điểm kiểm tra (nếu có)"
                        value={rating.diem_kt || ""}
                        onChange={(e) => handleRatingChange(sid, "diem_kt", e.target.value)}
                        className="input-control"
                        style={{ width: "100%", fontSize: "0.85rem" }}
                      />
                    </div>
                    <div>
                      <input
                        type="number"
                        placeholder="Điểm thưởng cộng (+10, +5)"
                        value={rating.diem_thuong || ""}
                        onChange={(e) => handleRatingChange(sid, "diem_thuong", e.target.value)}
                        className="input-control"
                        style={{ width: "100%", fontSize: "0.85rem" }}
                      />
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
