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
    lop_id: "",
    thu: "Thu2",
    gio_bat_dau: "17:30",
    gio_ket_thuc: "19:00",
    phong_hoc: "Phòng A1",
    ghi_chu: "",
  });

  useEffect(() => {
    // Load Classes
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
      }
    });

    // Load Schedules
    const schedRef = ref(db, "lich_hoc_chung");
    const unsubSched = onValue(schedRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = [];
        if (Array.isArray(val)) {
          list = val.map((item, idx) => (item ? { ...item, _key: item.id || idx } : null)).filter(Boolean);
        } else {
          list = Object.entries(val).map(([k, v]) => ({ ...v, _key: k }));
        }
        setSchedules(list);
      } else {
        setSchedules([]);
      }
      setLoading(false);
    });

    return () => {
      unsubClasses();
      unsubSched();
    };
  }, []);

  const handleOpenModal = (sched = null) => {
    if (sched) {
      setEditingSchedule(sched);
      setFormData({
        lop_id: sched.lop_id || "",
        thu: sched.thu || "Thu2",
        gio_bat_dau: sched.gio_bat_dau || "17:30",
        gio_ket_thuc: sched.gio_ket_thuc || "19:00",
        phong_hoc: sched.phong_hoc || "Phòng A1",
        ghi_chu: sched.ghi_chu || "",
      });
    } else {
      setEditingSchedule(null);
      setFormData({
        lop_id: classes[0]?._key || "",
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
    if (!formData.lop_id) {
      alert("Vui lòng chọn lớp học!");
      return;
    }

    try {
      if (editingSchedule) {
        const itemRef = ref(db, `lich_hoc_chung/${editingSchedule._key}`);
        await set(itemRef, {
          ...editingSchedule,
          ...formData,
          updated_at: new Date().toISOString(),
        });
      } else {
        const newId = Date.now();
        const itemRef = ref(db, `lich_hoc_chung/${newId}`);
        await set(itemRef, {
          id: newId,
          ...formData,
          created_at: new Date().toISOString(),
        });
      }
      setShowModal(false);
    } catch (err) {
      alert("Lỗi lưu ca học: " + err.message);
    }
  };

  const handleDelete = async (key) => {
    if (confirm("Bạn có chắc chắn muốn xóa ca học này khỏi thời khóa biểu?")) {
      try {
        await remove(ref(db, `lich_hoc_chung/${key}`));
      } catch (err) {
        alert("Lỗi xóa ca học: " + err.message);
      }
    }
  };

  const getClassName = (lopId) => {
    const cls = classes.find((c) => String(c._key) === String(lopId) || String(c.id) === String(lopId));
    return cls ? `${cls.ten_lop || cls.ten} (${cls.mon || "Môn học"})` : "Lớp #" + lopId;
  };

  const filteredSchedules = selectedDay === "ALL"
    ? schedules
    : schedules.filter((s) => s.thu === selectedDay);

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
            const dayObj = DAYS_OF_WEEK.find((d) => d.key === sc.thu);
            return (
              <div
                key={sc._key}
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
                      {dayObj ? dayObj.label : sc.thu}
                    </span>
                    <h4 style={{ fontSize: "1.1rem", fontWeight: "700" }}>{getClassName(sc.lop_id)}</h4>
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
                      onClick={() => handleDelete(sc._key)}
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
                    <span>Giờ học: <strong>{sc.gio_bat_dau || "17:30"} - {sc.gio_ket_thuc || "19:00"}</strong></span>
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
                  value={formData.lop_id}
                  onChange={(e) => setFormData({ ...formData, lop_id: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                  required
                >
                  <option value="">-- Chọn Lớp Học --</option>
                  {classes.map((c) => (
                    <option key={c._key} value={c._key}>
                      {c.ten_lop || c.ten} {c.mon ? `(${c.mon})` : ""}
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
