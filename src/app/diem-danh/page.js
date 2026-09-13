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
  BookOpen,
  Filter,
  Layers,
} from "lucide-react";

export default function DiemDanhPage() {
  const [classes, setClasses] = useState([]);
  const [students, setStudents] = useState([]);
  const [classStudents, setClassStudents] = useState([]);
  const [schedules, setSchedules] = useState([]);
  const [selectedClassId, setSelectedClassId] = useState("");
  const [showAllClassesTabs, setShowAllClassesTabs] = useState(false);

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
          setSelectedClassId(String(list[0]._key || list[0].id));
          setBuClassId(String(list[0]._key || list[0].id));
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

  // Find classes scheduled for current selected date
  const scheduledItems = schedules.filter((sc) => {
    if (!sc) return false;
    const thuKey = sc.thu || sc.thu_trong_tuan_str;
    const thuNum = Number(sc.thu_trong_tuan || sc.thuTrongTuan || sc.day_of_week);
    return thuKey === currentDayKey || thuNum === currentDayNum;
  });

  const scheduledClasses = classes.filter((c) => {
    const cid = String(c._key || c.id);
    return scheduledItems.some((sc) => String(sc.lop_id || sc.id_lop || sc.idLop) === cid);
  });

  // Determine active tabs to display (either scheduled classes, or all classes if toggle enabled / no schedule)
  const displayTabClasses = (scheduledClasses.length > 0 && !showAllClassesTabs)
    ? scheduledClasses
    : classes;

  // Auto select first scheduled class when attendanceDate changes
  useEffect(() => {
    if (scheduledClasses.length > 0) {
      const firstId = String(scheduledClasses[0]._key || scheduledClasses[0].id);
      setSelectedClassId(firstId);
    } else if (classes.length > 0) {
      const firstId = String(classes[0]._key || classes[0].id);
      setSelectedClassId(firstId);
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
    setAttendanceDate(buDate);
    setSelectedClassId(buClassId);
    setShowBuModal(false);
    setSuccessMsg(`Đã chuyển tới ngày ${buDate} để điểm danh bù cho lớp! Vui lòng điểm danh & nhấn 'Lưu Điểm Danh'.`);
    setTimeout(() => setSuccessMsg(""), 6000);
  };

  const currentClass = classes.find((c) => String(c._key || c.id) === String(selectedClassId));
  const currentSched = schedules.find(
    (sc) => String(sc.lop_id || sc.id_lop) === String(selectedClassId) && (sc.thu === currentDayKey || Number(sc.thu_trong_tuan) === currentDayNum)
  );

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
            Hiển thị các Lớp học có Lịch dạy trong ngày theo dạng Tab trực quan & tiện lợi
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
      </div>

      {/* 2. SCHEDULED CLASSES TABS BAR */}
      <div className="glass-panel" style={{ padding: "1.25rem", marginBottom: "1.5rem" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem", flexWrap: "wrap", gap: "0.5rem" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <Layers size={18} color="var(--accent-primary)" />
            <span style={{ fontWeight: "700", fontSize: "0.95rem" }}>
              LỊCH DẠY NỔI BẬT NÀY: {getDayOfWeekName(attendanceDate).toUpperCase()} ({scheduledClasses.length} lớp ca dạy)
            </span>
          </div>

          {classes.length > scheduledClasses.length && (
            <button
              type="button"
              onClick={() => setShowAllClassesTabs(!showAllClassesTabs)}
              style={{
                backgroundColor: "transparent",
                color: "var(--accent-primary)",
                border: "none",
                fontSize: "0.82rem",
                fontWeight: "600",
                cursor: "pointer",
                textDecoration: "underline",
              }}
            >
              {showAllClassesTabs ? "Thu gọn (Chỉ xem lịch hôm nay)" : `+ Xem tất cả ${classes.length} lớp học`}
            </button>
          )}
        </div>

        {/* Tab Headers */}
        {displayTabClasses.length === 0 ? (
          <div style={{ padding: "1.5rem", textAlign: "center", color: "var(--text-muted)", fontSize: "0.9rem" }}>
            Không có ca dạy nào được xếp vào ngày {getDayOfWeekName(attendanceDate)}. Bấm nút bên trên để xem tất cả các lớp.
          </div>
        ) : (
          <div
            style={{
              display: "flex",
              gap: "0.6rem",
              overflowX: "auto",
              paddingBottom: "0.4rem",
              scrollbarWidth: "thin",
            }}
          >
            {displayTabClasses.map((c) => {
              const cid = String(c._key || c.id);
              const isActive = String(cid) === String(selectedClassId);
              const matchedSched = schedules.find(
                (sc) => String(sc.lop_id || sc.id_lop) === cid && (sc.thu === currentDayKey || Number(sc.thu_trong_tuan) === currentDayNum)
              );

              return (
                <button
                  key={cid}
                  type="button"
                  onClick={() => setSelectedClassId(cid)}
                  style={{
                    padding: "0.75rem 1.25rem",
                    borderRadius: "12px",
                    border: isActive ? "2px solid var(--accent-primary)" : "1px solid var(--border-color)",
                    backgroundColor: isActive ? "var(--accent-primary)" : "var(--bg-secondary)",
                    color: isActive ? "#ffffff" : "var(--text-primary)",
                    fontWeight: isActive ? "700" : "600",
                    fontSize: "0.9rem",
                    cursor: "pointer",
                    display: "flex",
                    alignItems: "center",
                    gap: "0.55rem",
                    whiteSpace: "nowrap",
                    boxShadow: isActive ? "0 4px 14px var(--accent-glow)" : "none",
                    transition: "all 0.2s ease",
                  }}
                >
                  <span>{c.ten_lop || c.ten} {c.mon ? `(${c.mon})` : ""}</span>
                  {matchedSched ? (
                    <span
                      style={{
                        fontSize: "0.7rem",
                        backgroundColor: isActive ? "rgba(255,255,255,0.25)" : "rgba(16, 185, 129, 0.2)",
                        color: isActive ? "#ffffff" : "#10b981",
                        padding: "0.2rem 0.5rem",
                        borderRadius: "10px",
                        fontWeight: "700",
                      }}
                    >
                      ⏰ {matchedSched.gio_bat_dau || matchedSched.gioBatDau || "Ca dạy"} - {matchedSched.gio_ket_thuc || matchedSched.gioKetThuc || ""}
                    </span>
                  ) : (
                    <span
                      style={{
                        fontSize: "0.68rem",
                        backgroundColor: isActive ? "rgba(255,255,255,0.15)" : "rgba(255,255,255,0.05)",
                        color: isActive ? "#ffffff" : "var(--text-muted)",
                        padding: "0.15rem 0.4rem",
                        borderRadius: "8px",
                      }}
                    >
                      Khác lịch
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        )}
      </div>

      {/* Stats Summary Bar for Active Class */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))",
          gap: "1rem",
          marginBottom: "1.5rem",
        }}
      >
        <div className="glass-panel" style={{ padding: "1rem", textAlign: "center" }}>
          <div style={{ fontSize: "0.8rem", color: "var(--text-muted)", marginBottom: "0.25rem" }}>Sỉ số lớp này</div>
          <div style={{ fontSize: "1.4rem", fontWeight: "700" }}>{stats.total} Học sinh</div>
        </div>
        <div className="glass-panel" style={{ padding: "1rem", textAlign: "center", borderColor: "rgba(16, 185, 129, 0.3)" }}>
          <div style={{ fontSize: "0.8rem", color: "var(--success)", marginBottom: "0.25rem" }}>Có mặt</div>
          <div style={{ fontSize: "1.4rem", fontWeight: "700", color: "var(--success)" }}>{stats.coMat}</div>
        </div>
        <div className="glass-panel" style={{ padding: "1rem", textAlign: "center", borderColor: "rgba(245, 158, 11, 0.3)" }}>
          <div style={{ fontSize: "0.8rem", color: "var(--warning)", marginBottom: "0.25rem" }}>Vắng phép</div>
          <div style={{ fontSize: "1.4rem", fontWeight: "700", color: "var(--warning)" }}>{stats.vangPhep}</div>
        </div>
        <div className="glass-panel" style={{ padding: "1rem", textAlign: "center", borderColor: "rgba(239, 68, 68, 0.3)" }}>
          <div style={{ fontSize: "0.8rem", color: "var(--danger)", marginBottom: "0.25rem" }}>Vắng không phép</div>
          <div style={{ fontSize: "1.4rem", fontWeight: "700", color: "var(--danger)" }}>{stats.vangKhongPhep}</div>
        </div>
        <div className="glass-panel" style={{ padding: "1rem", textAlign: "center", borderColor: "rgba(249, 115, 22, 0.3)" }}>
          <div style={{ fontSize: "0.8rem", color: "#f97316", marginBottom: "0.25rem" }}>Đi muộn</div>
          <div style={{ fontSize: "1.4rem", fontWeight: "700", color: "#f97316" }}>{stats.muon}</div>
        </div>
      </div>

      {/* Tab Content: Active Class Student Roster Attendance */}
      <div className="glass-panel" style={{ padding: "1.5rem" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.25rem", flexWrap: "wrap", gap: "0.75rem" }}>
          <div>
            <h3 style={{ fontSize: "1.25rem", fontWeight: "700", display: "flex", alignItems: "center", gap: "0.5rem" }}>
              <BookOpen size={22} color="var(--accent-primary)" />
              Lớp: {currentClass?.ten_lop || currentClass?.ten || "Chọn Lớp"} {currentClass?.mon ? `(${currentClass.mon})` : ""}
            </h3>
            {currentSched && (
              <p style={{ fontSize: "0.82rem", color: "var(--success)", marginTop: "0.25rem", fontWeight: "600" }}>
                ⏰ Khung giờ dạy: {currentSched.gio_bat_dau || currentSched.gioBatDau} - {currentSched.gio_ket_thuc || currentSched.gioKetThuc} {currentSched.phong ? `| Phòng: ${currentSched.phong}` : ""}
              </p>
            )}
          </div>

          <div style={{ fontSize: "0.88rem", fontWeight: "600", color: "var(--text-secondary)" }}>
            Danh sách sỉ số: {filteredStudents.length} học sinh
          </div>
        </div>

        {loading ? (
          <div style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
            Đang nạp danh sách học sinh từ Realtime Cloud...
          </div>
        ) : filteredStudents.length === 0 ? (
          <div style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
            Chưa có học sinh nào được xếp vào lớp học này.
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: "0.85rem" }}>
            {filteredStudents.map((s, idx) => {
              const sid = s.id || s._key;
              const status = attendanceMap[sid] || "CoMat";
              const rating = ratingsMap[sid] || {};

              return (
                <div
                  key={sid}
                  style={{
                    padding: "1rem 1.25rem",
                    borderRadius: "12px",
                    backgroundColor: "var(--bg-secondary)",
                    border: "1px solid var(--border-color)",
                    display: "flex",
                    flexDirection: "column",
                    gap: "0.85rem",
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
                    {/* Student Info */}
                    <div style={{ display: "flex", alignItems: "center", gap: "0.85rem" }}>
                      <span
                        style={{
                          width: "32px",
                          height: "32px",
                          borderRadius: "50%",
                          backgroundColor: "rgba(13, 148, 136, 0.15)",
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                          fontWeight: "700",
                          fontSize: "0.85rem",
                          color: "var(--accent-primary)",
                        }}
                      >
                        {idx + 1}
                      </span>
                      <div>
                        <div style={{ fontWeight: "700", fontSize: "1.05rem" }}>{s.ten}</div>
                        <div style={{ fontSize: "0.78rem", color: "var(--text-muted)" }}>
                          SĐT Phụ Huynh: {s.sdt_phu_huynh || s.sdt || "--"} {s.truong ? `| Trường: ${s.truong}` : ""}
                        </div>
                      </div>
                    </div>

                    {/* Status Toggle Radio Buttons */}
                    <div style={{ display: "flex", gap: "0.4rem", flexWrap: "wrap" }}>
                      <button
                        type="button"
                        onClick={() => handleStatusChange(sid, "CoMat")}
                        style={{
                          padding: "0.45rem 0.8rem",
                          borderRadius: "8px",
                          fontSize: "0.85rem",
                          fontWeight: "600",
                          cursor: "pointer",
                          border: "none",
                          backgroundColor: status === "CoMat" ? "var(--success)" : "var(--bg-card)",
                          color: status === "CoMat" ? "#ffffff" : "var(--text-secondary)",
                          display: "flex",
                          alignItems: "center",
                          gap: "0.35rem",
                          transition: "all 0.2s ease",
                        }}
                      >
                        <CheckCircle size={15} /> Có Mặt
                      </button>

                      <button
                        type="button"
                        onClick={() => handleStatusChange(sid, "VangCoPhep")}
                        style={{
                          padding: "0.45rem 0.8rem",
                          borderRadius: "8px",
                          fontSize: "0.85rem",
                          fontWeight: "600",
                          cursor: "pointer",
                          border: "none",
                          backgroundColor: status === "VangCoPhep" ? "var(--warning)" : "var(--bg-card)",
                          color: status === "VangCoPhep" ? "#ffffff" : "var(--text-secondary)",
                          display: "flex",
                          alignItems: "center",
                          gap: "0.35rem",
                          transition: "all 0.2s ease",
                        }}
                      >
                        <Clock size={15} /> Vắng Có Phép
                      </button>

                      <button
                        type="button"
                        onClick={() => handleStatusChange(sid, "VangKhongPhep")}
                        style={{
                          padding: "0.45rem 0.8rem",
                          borderRadius: "8px",
                          fontSize: "0.85rem",
                          fontWeight: "600",
                          cursor: "pointer",
                          border: "none",
                          backgroundColor: status === "VangKhongPhep" ? "var(--danger)" : "var(--bg-card)",
                          color: status === "VangKhongPhep" ? "#ffffff" : "var(--text-secondary)",
                          display: "flex",
                          alignItems: "center",
                          gap: "0.35rem",
                          transition: "all 0.2s ease",
                        }}
                      >
                        <XCircle size={15} /> Vắng KP
                      </button>

                      <button
                        type="button"
                        onClick={() => handleStatusChange(sid, "Muon")}
                        style={{
                          padding: "0.45rem 0.8rem",
                          borderRadius: "8px",
                          fontSize: "0.85rem",
                          fontWeight: "600",
                          cursor: "pointer",
                          border: "none",
                          backgroundColor: status === "Muon" ? "#f97316" : "var(--bg-card)",
                          color: status === "Muon" ? "#ffffff" : "var(--text-secondary)",
                          display: "flex",
                          alignItems: "center",
                          gap: "0.35rem",
                          transition: "all 0.2s ease",
                        }}
                      >
                        <AlertCircle size={15} /> Đi Muộn
                      </button>
                    </div>
                  </div>

                  {/* Optional Comments & Scores Input */}
                  <div
                    style={{
                      display: "grid",
                      gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))",
                      gap: "0.75rem",
                      paddingTop: "0.65rem",
                      borderTop: "1px dashed var(--border-color)",
                    }}
                  >
                    <div>
                      <input
                        type="text"
                        placeholder="Nhận xét bài tập / thái độ học tập..."
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
          <div
            className="glass-panel"
            style={{ width: "100%", maxWidth: "480px", padding: "1.75rem", backgroundColor: "var(--bg-secondary)" }}
          >
            <h3 style={{ fontSize: "1.25rem", fontWeight: "700", marginBottom: "1.25rem" }}>
              ⚡ Điểm Danh Bù / Dạy Bù Ngày Quá Khứ
            </h3>

            <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Chọn ngày điểm danh bù *
                </label>
                <input
                  type="date"
                  value={buDate}
                  onChange={(e) => setBuDate(e.target.value)}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Chọn Lớp Học *
                </label>
                <select
                  value={buClassId}
                  onChange={(e) => setBuClassId(e.target.value)}
                  className="input-control"
                  style={{ width: "100%" }}
                >
                  {classes.map((c) => (
                    <option key={c._key || c.id} value={c._key || c.id}>
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
