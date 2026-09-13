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
  ChevronLeft,
  ChevronRight,
  Calendar as CalendarIcon,
  Sparkles,
  BookOpen
} from "lucide-react";

export default function DiemDanhPage() {
  const [classes, setClasses] = useState([]);
  const [students, setStudents] = useState([]);
  const [classStudents, setClassStudents] = useState([]);
  const [schedules, setSchedules] = useState([]);
  const [selectedClassId, setSelectedClassId] = useState("");

  // Date State - Default to Today YYYY-MM-DD
  const todayStr = new Date().toISOString().split("T")[0];
  const [attendanceDate, setAttendanceDate] = useState(todayStr);

  const [attendanceMap, setAttendanceMap] = useState({});
  const [ratingsMap, setRatingsMap] = useState({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [successMsg, setSuccessMsg] = useState("");

  // Modal State for Quick Diem Danh Bu / Day Bu
  const [showBuModal, setShowBuModal] = useState(false);
  const [buDate, setBuDate] = useState(todayStr);
  const [buClassId, setBuClassId] = useState("");
  const [buNote, setBuNote] = useState("");

  // Load Classes, Students, Schedules from Firebase Realtime DB
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
          setBuClassId(list[0]._key);
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
        let list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        setClassStudents(list);
      }
    });

    const schedRef = ref(db, "lich_hoc_chung");
    const unsubSched = onValue(schedRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        setSchedules(list);
      }
    });

    return () => {
      unsubClasses();
      unsubHs();
      unsubLopHs();
      unsubSched();
    };
  }, []);

  // Helper Date Functions for PickDate Controls
  const adjustDate = (daysOffset) => {
    const curDate = new Date(attendanceDate);
    curDate.setDate(curDate.getDate() + daysOffset);
    setAttendanceDate(curDate.toISOString().split("T")[0]);
  };

  const getDayOfWeekName = (dateString) => {
    const d = new Date(dateString);
    const dayIndex = d.getDay(); // 0 is Sunday, 1 is Monday...
    const days = [
      "Chủ Nhật",
      "Thứ Hai",
      "Thứ Ba",
      "Thứ Tư",
      "Thứ Năm",
      "Thứ Sáu",
      "Thứ Bảy",
    ];
    return days[dayIndex];
  };

  const getDayOfWeekKey = (dateString) => {
    const d = new Date(dateString);
    const dayIndex = d.getDay();
    const mapKeys = ["CN", "Thu2", "Thu3", "Thu4", "Thu5", "Thu6", "Thu7"];
    return mapKeys[dayIndex];
  };

  // Helper to convert Thu key to Number
  const getDayNumber = (thuKey) => {
    switch (thuKey) {
      case "Thu2": return 2;
      case "Thu3": return 3;
      case "Thu4": return 4;
      case "Thu5": return 5;
      case "Thu6": return 6;
      case "Thu7": return 7;
      case "CN": return 8;
      default: return 2;
    }
  };

  const currentDayKey = getDayOfWeekKey(attendanceDate);
  const currentDayNum = getDayNumber(currentDayKey);

  // Auto select first class that has schedule on selected attendanceDate
  useEffect(() => {
    if (classes.length === 0 || schedules.length === 0) return;
    const scheduledCls = classes.find((c) => {
      const cid = String(c._key || c.id);
      return schedules.some(
        (sc) => String(sc.lop_id || sc.id_lop) === cid && (sc.thu === currentDayKey || Number(sc.thuTrongTuan) === currentDayNum)
      );
    });
    if (scheduledCls) {
      setSelectedClassId(String(scheduledCls._key || scheduledCls.id));
    }
  }, [attendanceDate, schedules, classes]);

  // Strictly filter students enrolled in the selected class (NO dumping total students!)
  const targetStudentIds = classStudents
    .filter((cs) => {
      const cid = String(cs.lop_id || cs.id_lop);
      const st = String(cs.trang_thai || cs.status || "DANG_HOC").toUpperCase();
      return cid === String(selectedClassId) && st !== "DA_NGHI";
    })
    .map((cs) => String(cs.hoc_sinh_id || cs.id_hoc_sinh));

  const filteredStudents = students
    .filter((s) => {
      if (!s) return false;
      const sId = String(s.id || s._key);
      const sClassId = String(s.id_lop || s.lop_id || s.lopId || "");
      const st = String(s.trang_thai || s.status || s.trangThai || "").toUpperCase();
      if (st === "DA_NGHI" || st === "NGHI_HOC") return false;
      return targetStudentIds.includes(sId) || sClassId === String(selectedClassId);
    })
    .sort((a, b) => (a.ten || "").localeCompare(b.ten || "", "vi"));

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
      const timestamp = new Date().toISOString();

      // 1. Aggregated record for Web & Realtime query
      await set(ref(db, `diem_danh/${recordKey}`), {
        id: recordKey,
        lop_id: selectedClassId,
        id_lop: selectedClassId,
        ngay: attendanceDate,
        ngay_diem_danh: attendanceDate,
        danh_sach: attendanceMap,
        updated_at: timestamp,
      });

      // 2. Individual student records under diem_danh for Android SQLite sync compatibility
      for (const [studentId, status] of Object.entries(attendanceMap)) {
        const itemKey = `item_${selectedClassId}_${studentId}_${attendanceDate.replace(/-/g, "")}`;
        await set(ref(db, `diem_danh/${itemKey}`), {
          id: itemKey,
          id_lop: Number(selectedClassId) || selectedClassId,
          lop_id: Number(selectedClassId) || selectedClassId,
          id_hoc_sinh: Number(studentId) || studentId,
          hoc_sinh_id: Number(studentId) || studentId,
          ngay_diem_danh: attendanceDate,
          trang_thai: status,
          updated_at: timestamp,
        });
      }

      if (Object.keys(ratingsMap).length > 0) {
        await set(ref(db, `danh_gia_buoi_hoc/${recordKey}`), {
          id: recordKey,
          lop_id: selectedClassId,
          id_lop: selectedClassId,
          ngay: attendanceDate,
          danh_gia: ratingsMap,
          updated_at: timestamp,
        });
      }

      setSuccessMsg(`Đã lưu điểm danh lớp cho ngày ${attendanceDate} thành công! (Đồng bộ Cloud hoàn tất)`);
      setTimeout(() => setSuccessMsg(""), 5000);
    } catch (err) {
      alert("Lỗi khi lưu điểm danh: " + err.message);
    } finally {
      setSaving(false);
    }
  };

  const applyDiemDanhBu = () => {
    if (!buClassId || !buDate) return;
    setSelectedClassId(buClassId);
    setAttendanceDate(buDate);
    setShowBuModal(false);
    setSuccessMsg(`Đã chuyển tới ngày ${buDate} để điểm danh bù cho lớp! Vui lòng kiểm tra danh sách bên dưới & nhấn 'Lưu Điểm Danh'.`);
    setTimeout(() => setSuccessMsg(""), 6000);
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
      {/* Page Header */}
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          flexWrap: "wrap",
          gap: "1rem",
          marginBottom: "1.5rem",
        }}
      >
        <div>
          <h2 style={{ fontSize: "1.75rem", fontWeight: "700" }}>Điểm Danh Buổi Học</h2>
          <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem" }}>
            Công cụ PickDate thông minh & Điểm danh bù cho bất kỳ ngày nào trong quá khứ
          </p>
        </div>
        <div style={{ display: "flex", gap: "0.75rem", flexWrap: "wrap" }}>
          <button
            type="button"
            onClick={() => setShowBuModal(true)}
            className="btn-secondary"
            style={{
              display: "flex",
              alignItems: "center",
              gap: "0.5rem",
              padding: "0.75rem 1.25rem",
              backgroundColor: "rgba(245, 158, 11, 0.15)",
              color: "var(--warning)",
              border: "1px solid var(--warning)",
              fontWeight: "600",
            }}
          >
            <Sparkles size={18} />
            ⚡ Điểm Danh Bù / Dạy Bù
          </button>
          <button
            onClick={handleSaveAttendance}
            disabled={saving || filteredStudents.length === 0}
            className="btn-primary"
            style={{ display: "flex", alignItems: "center", gap: "0.5rem", padding: "0.75rem 1.25rem" }}
          >
            <Save size={18} />
            {saving ? "Đang Lưu Cloud..." : "Lưu Điểm Danh"}
          </button>
        </div>
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

      {/* 1. PICKDATE CONTROL BAR */}
      <div className="glass-panel" style={{ padding: "1.25rem", marginBottom: "1.5rem" }}>
        <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              flexWrap: "wrap",
              gap: "1rem",
            }}
          >
            {/* PickDate Widget with Arrows & Presets */}
            <div style={{ display: "flex", alignItems: "center", gap: "0.5rem", flexWrap: "wrap" }}>
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  backgroundColor: "var(--bg-secondary)",
                  borderRadius: "var(--radius-md)",
                  border: "1px solid var(--border-color)",
                  padding: "0.25rem",
                }}
              >
                <button
                  type="button"
                  onClick={() => adjustDate(-1)}
                  className="btn-secondary"
                  style={{ border: "none", padding: "0.5rem", borderRadius: "6px" }}
                  title="Ngày trước"
                >
                  <ChevronLeft size={18} />
                </button>

                <div style={{ padding: "0 0.75rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
                  <CalendarIcon size={18} color="var(--accent-primary)" />
                  <input
                    type="date"
                    value={attendanceDate}
                    onChange={(e) => setAttendanceDate(e.target.value)}
                    style={{
                      background: "transparent",
                      border: "none",
                      color: "var(--text-primary)",
                      fontWeight: "700",
                      fontSize: "1rem",
                      cursor: "pointer",
                      outline: "none",
                    }}
                  />
                </div>

                <button
                  type="button"
                  onClick={() => adjustDate(1)}
                  className="btn-secondary"
                  style={{ border: "none", padding: "0.5rem", borderRadius: "6px" }}
                  title="Ngày sau"
                >
                  <ChevronRight size={18} />
                </button>
              </div>

              {/* Preset Buttons */}
              <button
                type="button"
                onClick={() => setAttendanceDate(todayStr)}
                style={{
                  padding: "0.55rem 0.9rem",
                  borderRadius: "var(--radius-md)",
                  border: "1px solid var(--border-color)",
                  backgroundColor: attendanceDate === todayStr ? "var(--accent-primary)" : "var(--bg-secondary)",
                  color: attendanceDate === todayStr ? "#ffffff" : "var(--text-secondary)",
                  fontSize: "0.85rem",
                  fontWeight: "600",
                  cursor: "pointer",
                  transition: "var(--transition)",
                }}
              >
                Hôm nay
              </button>

              <button
                type="button"
                onClick={() => adjustDate(-1)}
                style={{
                  padding: "0.55rem 0.9rem",
                  borderRadius: "var(--radius-md)",
                  border: "1px solid var(--border-color)",
                  backgroundColor: "var(--bg-secondary)",
                  color: "var(--text-secondary)",
                  fontSize: "0.85rem",
                  fontWeight: "500",
                  cursor: "pointer",
                }}
              >
                Hôm qua
              </button>
            </div>

            {/* Date Display Badge */}
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: "0.5rem",
                fontSize: "0.95rem",
                fontWeight: "700",
                color: "var(--accent-primary)",
                backgroundColor: "rgba(13, 148, 136, 0.12)",
                padding: "0.5rem 1rem",
                borderRadius: "var(--radius-md)",
              }}
            >
              <Sparkles size={16} />
              <span>{getDayOfWeekName(attendanceDate)} ({attendanceDate.split("-").reverse().join("/")})</span>
            </div>
          </div>

          {/* 2. SMART CLASS SELECTOR CHIPS SORTED BY TIMETABLE SCHEDULE */}
          <div style={{ paddingTop: "0.75rem", borderTop: "1px dashed var(--border-color)" }}>
            <p style={{ fontSize: "0.8rem", fontWeight: "600", color: "var(--text-muted)", marginBottom: "0.6rem" }}>
              CHỌN LỚP ĐIỂM DANH (XẮP XẾP THEO LỊCH DẠY {getDayOfWeekName(attendanceDate).toUpperCase()}):
            </p>
            <div style={{ display: "flex", gap: "0.6rem", flexWrap: "wrap" }}>
              {[...classes]
                .sort((a, b) => {
                  const aCid = String(a._key || a.id);
                  const bCid = String(b._key || b.id);
                  const aHas = schedules.some(
                    (sc) => String(sc.lop_id || sc.id_lop) === aCid && (sc.thu === currentDayKey || Number(sc.thuTrongTuan) === currentDayNum)
                  );
                  const bHas = schedules.some(
                    (sc) => String(sc.lop_id || sc.id_lop) === bCid && (sc.thu === currentDayKey || Number(sc.thuTrongTuan) === currentDayNum)
                  );
                  if (aHas && !bHas) return -1;
                  if (!aHas && bHas) return 1;
                  return 0;
                })
                .map((c) => {
                  const cid = String(c._key || c.id);
                  const isSelected = String(cid) === String(selectedClassId);
                  const matchedSched = schedules.find(
                    (sc) => String(sc.lop_id || sc.id_lop) === cid && (sc.thu === currentDayKey || Number(sc.thuTrongTuan) === currentDayNum)
                  );

                  return (
                    <button
                      key={cid}
                      type="button"
                      onClick={() => setSelectedClassId(cid)}
                      style={{
                        padding: "0.6rem 1rem",
                        borderRadius: "var(--radius-md)",
                        border: isSelected ? "2px solid var(--accent-primary)" : "1px solid var(--border-color)",
                        backgroundColor: isSelected ? "var(--accent-primary)" : "var(--bg-secondary)",
                        color: isSelected ? "#ffffff" : "var(--text-primary)",
                        fontWeight: isSelected ? "700" : "500",
                        fontSize: "0.88rem",
                        cursor: "pointer",
                        display: "flex",
                        alignItems: "center",
                        gap: "0.5rem",
                        boxShadow: isSelected ? "0 4px 12px var(--accent-glow)" : "none",
                        transition: "all 0.2s ease",
                        position: "relative",
                      }}
                    >
                      <span>{c.ten_lop || c.ten} {c.mon ? `(${c.mon})` : ""}</span>
                      {matchedSched && (
                        <span
                          style={{
                            fontSize: "0.68rem",
                            backgroundColor: isSelected ? "rgba(255,255,255,0.25)" : "var(--success)",
                            color: "#ffffff",
                            padding: "0.15rem 0.4rem",
                            borderRadius: "10px",
                            fontWeight: "700",
                          }}
                        >
                          ⏰ {matchedSched.gio_bat_dau || matchedSched.gioBatDau || "Ca dạy"}
                        </span>
                      )}
                    </button>
                  );
                })}
            </div>
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

      {/* Student Attendance marking list */}
      <div className="glass-panel" style={{ padding: "1.5rem" }}>
        <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1.25rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
          <Users size={20} color="var(--accent-primary)" />
          Danh Sách Điểm Danh & Nhận Xét ({currentClass?.ten_lop || currentClass?.ten || "Lớp"})
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

      {/* DIEM DANH BU MODAL */}
      {showBuModal && (
        <div
          style={{
            position: "fixed",
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: "rgba(0, 0, 0, 0.75)",
            backdropFilter: "blur(4px)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            zIndex: 9999,
            padding: "1rem",
          }}
        >
          <div
            className="glass-panel"
            style={{
              width: "100%",
              maxWidth: "500px",
              padding: "1.75rem",
              borderRadius: "var(--radius-lg)",
              backgroundColor: "var(--bg-card)",
              border: "1px solid var(--border-color)",
              boxShadow: "0 20px 25px -5px rgba(0, 0, 0, 0.5)",
            }}
          >
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.25rem" }}>
              <h3 style={{ fontSize: "1.25rem", fontWeight: "700", display: "flex", alignItems: "center", gap: "0.5rem", color: "var(--warning)" }}>
                <Sparkles size={20} />
                Điểm Danh Bù / Buổi Dạy Bù
              </h3>
              <button
                type="button"
                onClick={() => setShowBuModal(false)}
                style={{
                  background: "none",
                  border: "none",
                  color: "var(--text-muted)",
                  cursor: "pointer",
                  fontSize: "1.25rem",
                }}
              >
                ✕
              </button>
            </div>

            <p style={{ fontSize: "0.88rem", color: "var(--text-secondary)", marginBottom: "1.25rem" }}>
              Chọn ngày cần điểm danh bù trong quá khứ và lớp học tương ứng. Hệ thống sẽ mở dữ liệu ngày đó để bạn cập nhật điểm danh và đồng bộ Cloud lập tức.
            </p>

            <div style={{ display: "flex", flexDirection: "column", gap: "1rem", marginBottom: "1.5rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", color: "var(--text-muted)", marginBottom: "0.4rem" }}>
                  1. CHỌN NGÀY HỌC BÙ / CẦN ĐIỂM DANH BÙ:
                </label>
                <input
                  type="date"
                  value={buDate}
                  onChange={(e) => setBuDate(e.target.value)}
                  className="input-control"
                  style={{ width: "100%", fontWeight: "600" }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", color: "var(--text-muted)", marginBottom: "0.4rem" }}>
                  2. CHỌN LỚP HỌC:
                </label>
                <select
                  value={buClassId}
                  onChange={(e) => setBuClassId(e.target.value)}
                  className="input-control"
                  style={{ width: "100%", fontWeight: "600" }}
                >
                  {classes.map((c) => (
                    <option key={c._key} value={c._key}>
                      {c.ten_lop || c.ten} {c.mon ? `(${c.mon})` : ""}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", color: "var(--text-muted)", marginBottom: "0.4rem" }}>
                  3. GHI CHÚ BUỔI HỌC BÙ (NẾU CÓ):
                </label>
                <input
                  type="text"
                  placeholder="Ví dụ: Học bù ca 2 Thứ 3 tuần trước..."
                  value={buNote}
                  onChange={(e) => setBuNote(e.target.value)}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>
            </div>

            <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem" }}>
              <button
                type="button"
                onClick={() => setShowBuModal(false)}
                className="btn-secondary"
              >
                Hủy Bỏ
              </button>
              <button
                type="button"
                onClick={applyDiemDanhBu}
                className="btn-primary"
                style={{ backgroundColor: "var(--warning)", color: "#000000", fontWeight: "700" }}
              >
                Mở Điểm Danh Bù Ngày {buDate}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
