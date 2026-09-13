"use client";

import { useEffect, useState } from "react";
import { db, ref, onValue, set, remove } from "@/lib/firebase";
import {
  Calendar,
  Clock,
  Plus,
  Edit,
  Trash2,
  Users,
  MapPin,
  GraduationCap,
  Filter
} from "lucide-react";

const DAYS_OF_WEEK = [
  { key: "Thu2", label: "Thứ Hai" },
  { key: "Thu3", label: "Thứ Ba" },
  { key: "Thu4", label: "Thứ Tư" },
  { key: "Thu5", label: "Thứ Năm" },
  { key: "Thu6", label: "Thứ Sáu" },
  { key: "Thu7", label: "Thứ Bảy" },
  { key: "CN", label: "Chủ Nhật" },
];

export default function LichDayPage() {
  const [schedules, setSchedules] = useState([]);
  const [classes, setClasses] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedDay, setSelectedDay] = useState("ALL");
  const [showModal, setShowModal] = useState(false);
  const [editingSchedule, setEditingSchedule] = useState(null);

  // Form State
  const [formData, setFormData] = useState({
    id_lop: "",
    thu: "Thu2",
    gio_bat_dau: "17:30",
    gio_ket_thuc: "19:00",
    phong_hoc: "Phòng A1",
    ghi_chu: "",
  });

  useEffect(() => {
    // 1. Load Classes from both 'lop' and 'lop_hoc' nodes
    let listLop1 = [];
    let listLop2 = [];

    const mergeClasses = () => {
      const combined = [...listLop1, ...listLop2];
      const map = new Map();
      combined.forEach((c) => {
        const key = String(c.id || c._key);
        if (!map.has(key)) map.set(key, c);
      });
      setClasses(Array.from(map.values()));
    };

    const lopRef1 = ref(db, "lop");
    const unsubLop1 = onValue(lopRef1, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        listLop1 = Array.isArray(val)
          ? val.map((item, idx) => (item ? { ...item, _key: item.id || idx } : null)).filter(Boolean)
          : Object.entries(val).map(([k, v]) => ({ ...v, _key: k }));
      } else {
        listLop1 = [];
      }
      mergeClasses();
    });

    const lopRef2 = ref(db, "lop_hoc");
    const unsubLop2 = onValue(lopRef2, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        listLop2 = Array.isArray(val)
          ? val.map((item, idx) => (item ? { ...item, _key: item.id || idx } : null)).filter(Boolean)
          : Object.entries(val).map(([k, v]) => ({ ...v, _key: k }));
      } else {
        listLop2 = [];
      }
      mergeClasses();
    });

    // 2. Load Schedules from both 'lich_hoc_chung' and 'lich_hoc' nodes
    let listSched1 = [];
    let listSched2 = [];

    const mergeSchedules = () => {
      const combined = [...listSched1, ...listSched2];
      const map = new Map();
      combined.forEach((sc) => {
        const key = String(sc.id || sc._key);
        if (!map.has(key)) map.set(key, sc);
      });
      setSchedules(Array.from(map.values()));
      setLoading(false);
    };

    const schedRef1 = ref(db, "lich_hoc_chung");
    const unsubSched1 = onValue(schedRef1, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        listSched1 = Array.isArray(val)
          ? val.map((item, idx) => (item ? { ...item, _key: item.id || idx } : null)).filter(Boolean)
          : Object.entries(val).map(([k, v]) => ({ ...v, _key: k }));
      } else {
        listSched1 = [];
      }
      mergeSchedules();
    });

    const schedRef2 = ref(db, "lich_hoc");
    const unsubSched2 = onValue(schedRef2, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        listSched2 = Array.isArray(val)
          ? val.map((item, idx) => (item ? { ...item, _key: item.id || idx } : null)).filter(Boolean)
          : Object.entries(val).map(([k, v]) => ({ ...v, _key: k }));
      } else {
        listSched2 = [];
      }
      mergeSchedules();
    });

    return () => {
      unsubLop1();
      unsubLop2();
      unsubSched1();
      unsubSched2();
    };
  }, []);

  const handleOpenModal = (sched = null) => {
    if (sched) {
      setEditingSchedule(sched);
      setFormData({
        id_lop: String(sched.id_lop || sched.lop_id || sched.idLop || ""),
        thu: normalizeDayKey(sched),
        gio_bat_dau: sched.gio_bat_dau || sched.gioBatDau || "17:30",
        gio_ket_thuc: sched.gio_ket_thuc || sched.gioKetThuc || "19:00",
        phong_hoc: sched.phong_hoc || "Phòng học chính",
        ghi_chu: sched.ghi_chu || "",
      });
    } else {
      setEditingSchedule(null);
      setFormData({
        id_lop: classes[0] ? String(classes[0].id || classes[0]._key) : "",
        thu: "Thu2",
        gio_bat_dau: "17:30",
        gio_ket_thuc: "19:00",
        phong_hoc: "Phòng A1",
        ghi_chu: "",
      });
    }
    setShowModal(true);
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!formData.id_lop) {
      alert("Vui lòng chọn lớp học!");
      return;
    }

    try {
      const newId = editingSchedule ? (editingSchedule.id || editingSchedule._key) : Date.now();
      const payload = {
        id: Number(newId) || newId,
        id_lop: Number(formData.id_lop) || formData.id_lop,
        lop_id: Number(formData.id_lop) || formData.id_lop,
        idLop: Number(formData.id_lop) || formData.id_lop,
        thu: formData.thu,
        thuTrongTuan: getDayNumber(formData.thu),
        gio_bat_dau: formData.gio_bat_dau,
        gioBatDau: formData.gio_bat_dau,
        gio_ket_thuc: formData.gio_ket_thuc,
        gioKetThuc: formData.gio_ket_thuc,
        phong_hoc: formData.phong_hoc,
        ghi_chu: formData.ghi_chu,
        updated_at: new Date().toISOString(),
      };

      await set(ref(db, `lich_hoc_chung/${newId}`), payload);
      await set(ref(db, `lich_hoc/${newId}`), payload);

      setShowModal(false);
    } catch (err) {
      alert("Lỗi lưu ca học: " + err.message);
    }
  };

  const handleDelete = async (sc) => {
    const key = sc._key || sc.id;
    if (confirm("Bạn có chắc chắn muốn xóa ca học này khỏi thời khóa biểu?")) {
      try {
        await remove(ref(db, `lich_hoc_chung/${key}`));
        await remove(ref(db, `lich_hoc/${key}`));
      } catch (err) {
        alert("Lỗi xóa ca học: " + err.message);
      }
    }
  };

  // Helper function to extract class name safely
  const getClassName = (sc) => {
    const targetId = sc.id_lop ?? sc.lop_id ?? sc.idLop;
    if (targetId === undefined || targetId === null) return "Lớp Học";
    const cls = classes.find(
      (c) => String(c.id) === String(targetId) || String(c._key) === String(targetId)
    );
    if (cls) {
      const name = cls.ten || cls.ten_lop || `Lớp #${targetId}`;
      return cls.khoi ? `${name} (Khối ${cls.khoi})` : name;
    }
    return `Lớp #${targetId}`;
  };

  // Helper function to normalize day of week
  const normalizeDayKey = (sc) => {
    const val = sc.thu ?? sc.thuTrongTuan ?? sc.ngay_trong_tuan ?? sc.thu_trong_tuan;
    if (val === undefined || val === null) return "Thu2";
    const str = String(val).toLowerCase();
    if (str === "2" || str.includes("thu2") || str.includes("thứ hai") || str.includes("thứ 2") || str.includes("monday")) return "Thu2";
    if (str === "3" || str.includes("thu3") || str.includes("thứ ba") || str.includes("thứ 3") || str.includes("tuesday")) return "Thu3";
    if (str === "4" || str.includes("thu4") || str.includes("thứ tư") || str.includes("thứ 4") || str.includes("wednesday")) return "Thu4";
    if (str === "5" || str.includes("thu5") || str.includes("thứ năm") || str.includes("thứ 5") || str.includes("thursday")) return "Thu5";
    if (str === "6" || str.includes("thu6") || str.includes("thứ sáu") || str.includes("thứ 6") || str.includes("friday")) return "Thu6";
    if (str === "7" || str.includes("thu7") || str.includes("thứ bảy") || str.includes("thứ 7") || str.includes("saturday")) return "Thu7";
    if (str === "8" || str === "1" || str.includes("cn") || str.includes("chủ nhật") || str.includes("sunday")) return "CN";
    return "Thu2";
  };

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

  const filteredSchedules = selectedDay === "ALL"
    ? schedules
    : schedules.filter((s) => normalizeDayKey(s) === selectedDay);

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
          <h2 style={{ fontSize: "1.75rem", fontWeight: "700" }}>Lịch Dạy & Thời Khóa Biểu</h2>
          <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem" }}>
            Quản lý các ca dạy hàng tuần cho giáo viên
          </p>
        </div>
        <button onClick={() => handleOpenModal()} className="btn-primary">
          <Plus size={18} /> Thêm Ca Dạy Mới
        </button>
      </div>

      {/* Day Selector Bar */}
      <div
        style={{
          display: "flex",
          gap: "0.5rem",
          overflowX: "auto",
          paddingBottom: "0.5rem",
          marginBottom: "1.5rem",
        }}
      >
        <button
          onClick={() => setSelectedDay("ALL")}
          style={{
            padding: "0.6rem 1.25rem",
            borderRadius: "var(--radius-md)",
            fontSize: "0.9rem",
            fontWeight: "600",
            cursor: "pointer",
            border: "none",
            backgroundColor: selectedDay === "ALL" ? "var(--accent-primary)" : "var(--bg-card)",
            color: selectedDay === "ALL" ? "#ffffff" : "var(--text-secondary)",
            transition: "var(--transition)",
            whiteSpace: "nowrap",
          }}
        >
          Tất Cả Các Ngày
        </button>
        {DAYS_OF_WEEK.map((day) => (
          <button
            key={day.key}
            onClick={() => setSelectedDay(day.key)}
            style={{
              padding: "0.6rem 1.25rem",
              borderRadius: "var(--radius-md)",
              fontSize: "0.9rem",
              fontWeight: "600",
              cursor: "pointer",
              border: "none",
              backgroundColor: selectedDay === day.key ? "var(--accent-primary)" : "var(--bg-card)",
              color: selectedDay === day.key ? "#ffffff" : "var(--text-secondary)",
              transition: "var(--transition)",
              whiteSpace: "nowrap",
            }}
          >
            {day.label}
          </button>
        ))}
      </div>

      {/* Schedule Grid / List */}
      {loading ? (
        <div style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
          Đang tải lịch dạy từ Realtime Cloud...
        </div>
      ) : filteredSchedules.length === 0 ? (
        <div className="glass-panel" style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
          Không có ca dạy nào trong khoảng thời gian đã chọn.
        </div>
      ) : (
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fill, minmax(320px, 1fr))",
            gap: "1.25rem",
          }}
        >
          {filteredSchedules.map((sc) => {
            const dayKey = normalizeDayKey(sc);
            const dayObj = DAYS_OF_WEEK.find((d) => d.key === dayKey);
            const startTime = sc.gio_bat_dau || sc.gioBatDau || "17:30";
            const endTime = sc.gio_ket_thuc || sc.gioKetThuc || "19:00";

            return (
              <div
                key={sc._key || sc.id}
                className="glass-panel hover-card"
                style={{ padding: "1.25rem", display: "flex", flexDirection: "column", gap: "1rem" }}
              >
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
                  <div>
                    <span
                      style={{
                        fontSize: "0.75rem",
                        fontWeight: "700",
                        padding: "0.25rem 0.6rem",
                        borderRadius: "12px",
                        backgroundColor: "rgba(13, 148, 136, 0.15)",
                        color: "var(--accent-primary)",
                        display: "inline-block",
                        marginBottom: "0.5rem",
                      }}
                    >
                      {dayObj ? dayObj.label : dayKey}
                    </span>
                    <h4 style={{ fontSize: "1.1rem", fontWeight: "700" }}>{getClassName(sc)}</h4>
                  </div>

                  <div style={{ display: "flex", gap: "0.35rem" }}>
                    <button
                      onClick={() => handleOpenModal(sc)}
                      className="btn-secondary"
                      style={{ padding: "0.35rem 0.5rem" }}
                      title="Chỉnh sửa"
                    >
                      <Edit size={14} />
                    </button>
                    <button
                      onClick={() => handleDelete(sc)}
                      className="btn-secondary"
                      style={{ padding: "0.35rem 0.5rem", color: "var(--danger)", borderColor: "rgba(239, 68, 68, 0.3)" }}
                      title="Xóa"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>

                <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem", fontSize: "0.9rem", color: "var(--text-secondary)" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                    <Clock size={16} color="var(--accent-primary)" />
                    <span>Giờ học: <strong>{startTime} - {endTime}</strong></span>
                  </div>
                  <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                    <MapPin size={16} color="var(--accent-primary)" />
                    <span>Địa điểm: {sc.phong_hoc || "Phòng học chính"}</span>
                  </div>
                  {sc.ghi_chu && (
                    <div style={{ fontSize: "0.8rem", color: "var(--text-muted)", marginTop: "0.25rem" }}>
                      Ghi chú: {sc.ghi_chu}
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Modal Dialog Add/Edit Schedule */}
      {showModal && (
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
          <div className="glass-panel" style={{ width: "100%", maxWidth: "500px", padding: "1.75rem", backgroundColor: "var(--bg-secondary)" }}>
            <h3 style={{ fontSize: "1.25rem", fontWeight: "700", marginBottom: "1.25rem" }}>
              {editingSchedule ? "Chỉnh Sửa Ca Dạy" : "Thêm Ca Dạy Mới"}
            </h3>

            <form onSubmit={handleSave} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Lớp Học *
                </label>
                <select
                  value={formData.id_lop}
                  onChange={(e) => setFormData({ ...formData, id_lop: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                  required
                >
                  <option value="">-- Chọn Lớp Học --</option>
                  {classes.map((c) => (
                    <option key={c.id || c._key} value={c.id || c._key}>
                      {c.ten || c.ten_lop} {c.mon ? `(${c.mon})` : ""} {c.khoi ? `- Khối ${c.khoi}` : ""}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Thứ Trong Tuần
                </label>
                <select
                  value={formData.thu}
                  onChange={(e) => setFormData({ ...formData, thu: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                >
                  {DAYS_OF_WEEK.map((d) => (
                    <option key={d.key} value={d.key}>
                      {d.label}
                    </option>
                  ))}
                </select>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem" }}>
                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                    Giờ Bắt Đầu
                  </label>
                  <input
                    type="time"
                    value={formData.gio_bat_dau}
                    onChange={(e) => setFormData({ ...formData, gio_bat_dau: e.target.value })}
                    className="input-control"
                    style={{ width: "100%" }}
                  />
                </div>

                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                    Giờ Kết Thúc
                  </label>
                  <input
                    type="time"
                    value={formData.gio_ket_thuc}
                    onChange={(e) => setFormData({ ...formData, gio_ket_thuc: e.target.value })}
                    className="input-control"
                    style={{ width: "100%" }}
                  />
                </div>
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Phòng Học / Địa Điểm
                </label>
                <input
                  type="text"
                  placeholder="Ví dụ: Phòng A1, Tầng 2"
                  value={formData.phong_hoc}
                  onChange={(e) => setFormData({ ...formData, phong_hoc: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Ghi Chú
                </label>
                <input
                  type="text"
                  placeholder="Ghi chú buổi dạy..."
                  value={formData.ghi_chu}
                  onChange={(e) => setFormData({ ...formData, ghi_chu: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "1rem" }}>
                <button type="button" onClick={() => setShowModal(false)} className="btn-secondary">
                  Hủy
                </button>
                <button type="submit" className="btn-primary">
                  {editingSchedule ? "Cập Nhật" : "Tạo Ca Học"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
