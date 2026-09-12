"use client";

import { useEffect, useState } from "react";
import { db, ref, onValue, set, remove } from "@/lib/firebase";
import Link from "next/link";
import { GraduationCap, Plus, Search, Edit, Trash2, Users, BookOpen } from "lucide-react";

export default function LopHocPage() {
  const [classes, setClasses] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingLop, setEditingLop] = useState(null);

  const [formData, setFormData] = useState({
    ten: "",
    khoi: 10,
    hoc_phi_buoi: 50000,
    mo_ta: "",
  });

  useEffect(() => {
    const lopRef = ref(db, "lop");
    const unsub = onValue(lopRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = [];
        if (Array.isArray(val)) {
          list = val
            .map((item, idx) => (item ? { ...item, _key: item.id || idx } : null))
            .filter(Boolean);
        } else if (typeof val === "object") {
          list = Object.entries(val).map(([key, item]) => ({
            ...item,
            _key: key,
          }));
        }
        setClasses(list);
      } else {
        setClasses([]);
      }
      setLoading(false);
    });

    return () => unsub();
  }, []);

  const handleOpenModal = (lop = null) => {
    if (lop) {
      setEditingLop(lop);
      setFormData({
        ten: lop.ten || "",
        khoi: lop.khoi || 10,
        hoc_phi_buoi: lop.hoc_phi_buoi || 50000,
        mo_ta: lop.mo_ta || "",
      });
    } else {
      setEditingLop(null);
      setFormData({
        ten: "",
        khoi: 10,
        hoc_phi_buoi: 50000,
        mo_ta: "",
      });
    }
    setShowModal(true);
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!formData.ten.trim()) return;

    try {
      if (editingLop) {
        const itemRef = ref(db, `lop/${editingLop._key}`);
        await set(itemRef, {
          ...editingLop,
          ...formData,
          updated_at: new Date().toISOString(),
        });
      } else {
        const newId = Date.now();
        const itemRef = ref(db, `lop/${newId}`);
        await set(itemRef, {
          id: newId,
          ...formData,
          created_at: new Date().toISOString(),
        });
      }
      setShowModal(false);
    } catch (err) {
      alert("Lỗi lưu lớp học: " + err.message);
    }
  };

  const handleDelete = async (key) => {
    if (confirm("Bạn có chắc chắn muốn xóa lớp học này?")) {
      try {
        await remove(ref(db, `lop/${key}`));
      } catch (err) {
        alert("Lỗi xóa lớp học: " + err.message);
      }
    }
  };

  const formatCurrency = (num) => {
    return new Intl.NumberFormat("vi-VN", {
      style: "currency",
      currency: "VND",
    }).format(num);
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
          <h2 style={{ fontSize: "1.75rem", fontWeight: "700" }}>Quản Lý Lớp Học</h2>
          <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem" }}>
            Danh sách các lớp giảng dạy, học phí mỗi buổi và phân loại khối
          </p>
        </div>
        <button onClick={() => handleOpenModal()} className="btn-primary">
          <Plus size={18} /> Tạo Lớp Học Mới
        </button>
      </div>

      {/* Class Cards Grid */}
      {loading ? (
        <div style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
          Đang nạp danh sách lớp học...
        </div>
      ) : classes.length === 0 ? (
        <div className="glass-panel" style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
          Chưa có lớp học nào được tạo. Nhấp nút "Tạo Lớp Học Mới" để thêm lớp.
        </div>
      ) : (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(320px, 1fr))", gap: "1.25rem" }}>
          {classes.map((c) => (
            <div key={c._key} className="glass-card" style={{ display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
              <div>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "0.75rem" }}>
                  <div>
                    <span className="badge badge-info" style={{ marginBottom: "0.5rem" }}>
                      Khối {c.khoi || "Khác"}
                    </span>
                    <h3 style={{ fontSize: "1.25rem", fontWeight: "700" }}>{c.ten}</h3>
                  </div>
                  <div style={{ display: "flex", gap: "0.35rem" }}>
                    <button
                      onClick={() => handleOpenModal(c)}
                      className="btn-secondary"
                      style={{ padding: "0.35rem 0.5rem" }}
                    >
                      <Edit size={14} />
                    </button>
                    <button
                      onClick={() => handleDelete(c._key)}
                      className="btn-secondary"
                      style={{ padding: "0.35rem 0.5rem", color: "var(--danger)", borderColor: "rgba(239, 68, 68, 0.3)" }}
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>

                <p style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginBottom: "1rem" }}>
                  {c.mo_ta || "Chưa có mô tả cho lớp học này."}
                </p>
              </div>

              <div style={{ borderTop: "1px solid var(--border-color)", paddingTop: "0.75rem", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div>
                  <span style={{ fontSize: "0.8rem", color: "var(--text-muted)", display: "block" }}>Học phí / Buổi:</span>
                  <span style={{ fontWeight: "700", color: "var(--accent-primary)", fontSize: "1.05rem" }}>
                    {formatCurrency(c.hoc_phi_buoi || 0)}
                  </span>
                </div>
                <Link
                  href={`/lop-hoc/${c.id || c._key}`}
                  className="btn-primary"
                  style={{ padding: "0.45rem 0.85rem", fontSize: "0.8rem", textDecoration: "none" }}
                >
                  Chi Tiết Lớp &rarr;
                </Link>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Modal Add/Edit Class */}
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
          <div className="glass-panel" style={{ width: "100%", maxWidth: "480px", padding: "1.75rem", backgroundColor: "var(--bg-secondary)" }}>
            <h3 style={{ fontSize: "1.25rem", fontWeight: "700", marginBottom: "1.25rem" }}>
              {editingLop ? "Chỉnh Sửa Lớp Học" : "Tạo Lớp Học Mới"}
            </h3>

            <form onSubmit={handleSave} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Tên lớp học *
                </label>
                <input
                  type="text"
                  required
                  placeholder="Ví dụ: Toán 12 Nâng Cao"
                  value={formData.ten}
                  onChange={(e) => setFormData({ ...formData, ten: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem" }}>
                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                    Khối học
                  </label>
                  <input
                    type="number"
                    value={formData.khoi}
                    onChange={(e) => setFormData({ ...formData, khoi: Number(e.target.value) })}
                    className="input-control"
                    style={{ width: "100%" }}
                  />
                </div>
                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                    Học phí 1 buổi (VND)
                  </label>
                  <input
                    type="number"
                    step={5000}
                    value={formData.hoc_phi_buoi}
                    onChange={(e) => setFormData({ ...formData, hoc_phi_buoi: Number(e.target.value) })}
                    className="input-control"
                    style={{ width: "100%" }}
                  />
                </div>
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Mô tả chi tiết
                </label>
                <textarea
                  rows={3}
                  placeholder="Ví dụ: Lịch học Tối thứ 2, thứ 5..."
                  value={formData.mo_ta}
                  onChange={(e) => setFormData({ ...formData, mo_ta: e.target.value })}
                  className="input-control"
                  style={{ width: "100%", resize: "vertical" }}
                />
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "1rem" }}>
                <button type="button" onClick={() => setShowModal(false)} className="btn-secondary">
                  Hủy
                </button>
                <button type="submit" className="btn-primary">
                  {editingLop ? "Cập Nhật" : "Tạo Lớp"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
