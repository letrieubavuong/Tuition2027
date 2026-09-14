"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { db, ref, onValue, set, remove } from "@/lib/firebase";
import StudentQRModal from "@/components/StudentQRModal";
import {
  Users,
  Search,
  Plus,
  Trash2,
  Edit,
  Phone,
  Filter,
  Eye,
  GraduationCap,
  Grid,
  List,
  MessageCircle,
  QrCode
} from "lucide-react";

export default function HocSinhPage() {
  const [students, setStudents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [viewMode, setViewMode] = useState("grid"); // 'grid' | 'table'
  const [showModal, setShowModal] = useState(false);
  const [editingHs, setEditingHs] = useState(null);
  const [qrStudent, setQrStudent] = useState(null);

  // Form State
  const [formData, setFormData] = useState({
    ten: "",
    sdt_phu_huynh: "",
    email: "",
    truong: "",
    ghi_chu: "",
  });

  useEffect(() => {
    const hsRef = ref(db, "hoc_sinh");
    const unsub = onValue(hsRef, (snapshot) => {
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
        setStudents(list);
      } else {
        setStudents([]);
      }
      setLoading(false);
    });

    return () => unsub();
  }, []);

  const getSchoolName = (s) => s?.truong_dang_hoc || s?.truong || s?.ten_truong || s?.truong_hoc || "";

  const handleOpenModal = (hs = null) => {
    if (hs) {
      setEditingHs(hs);
      setFormData({
        ten: hs.ten || "",
        sdt_phu_huynh: hs.sdt_phu_huynh || hs.sdt || "",
        email: hs.email || "",
        truong: getSchoolName(hs),
        ghi_chu: hs.ghi_chu || "",
      });
    } else {
      setEditingHs(null);
      setFormData({
        ten: "",
        sdt_phu_huynh: "",
        email: "",
        truong: "",
        ghi_chu: "",
      });
    }
    setShowModal(true);
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!formData.ten.trim()) return;

    try {
      if (editingHs) {
        const itemRef = ref(db, `hoc_sinh/${editingHs._key}`);
        await set(itemRef, {
          ...editingHs,
          ...formData,
          truong_dang_hoc: formData.truong,
          updated_at: new Date().toISOString(),
        });
      } else {
        const newId = Date.now();
        const itemRef = ref(db, `hoc_sinh/${newId}`);
        await set(itemRef, {
          id: newId,
          ...formData,
          truong_dang_hoc: formData.truong,
          created_at: new Date().toISOString(),
        });
      }
      setShowModal(false);
    } catch (err) {
      alert("Lỗi lưu học sinh: " + err.message);
    }
  };

  const handleDelete = async (key) => {
    if (confirm("Bạn có chắc chắn muốn xóa học sinh này?")) {
      try {
        await remove(ref(db, `hoc_sinh/${key}`));
      } catch (err) {
        alert("Lỗi xóa học sinh: " + err.message);
      }
    }
  };

  const filteredStudents = students.filter(
    (s) =>
      (s.ten && s.ten.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (s.sdt_phu_huynh && s.sdt_phu_huynh.includes(searchQuery)) ||
      (s.sdt && s.sdt.includes(searchQuery)) ||
      (getSchoolName(s) && getSchoolName(s).toLowerCase().includes(searchQuery.toLowerCase()))
  );

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
          marginBottom: "1.75rem",
        }}
      >
        <div>
          <h2 style={{ fontSize: "1.75rem", fontWeight: "700" }}>Quản Lý Học Sinh</h2>
          <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem" }}>
            Danh sách học sinh theo dạng Card nhiều cột hiện đại & tiện lợi
          </p>
        </div>
        <button onClick={() => handleOpenModal()} className="btn-primary">
          <Plus size={18} /> Thêm Học Sinh Mới
        </button>
      </div>

      {/* Filter & View Mode Controls */}
      <div className="glass-panel" style={{ padding: "1rem 1.25rem", marginBottom: "1.5rem" }}>
        <div
          style={{
            display: "flex",
            gap: "1rem",
            alignItems: "center",
            justifyContent: "space-between",
            flexWrap: "wrap",
          }}
        >
          <div style={{ position: "relative", flex: 1, minWidth: "260px" }}>
            <Search
              size={18}
              color="var(--text-muted)"
              style={{ position: "absolute", left: "1rem", top: "50%", transform: "translateY(-50%)" }}
            />
            <input
              type="text"
              placeholder="Tìm kiếm theo tên học sinh, SĐT phụ huynh, trường học..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="input-control"
              style={{ width: "100%", paddingLeft: "2.75rem" }}
            />
          </div>

          <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
            <div style={{ display: "flex", alignItems: "center", gap: "0.4rem", color: "var(--text-secondary)" }}>
              <Filter size={18} />
              <span style={{ fontSize: "0.9rem", fontWeight: "600" }}>{filteredStudents.length} Học sinh</span>
            </div>

            {/* View Mode Toggle Buttons */}
            <div
              style={{
                display: "flex",
                backgroundColor: "rgba(255, 255, 255, 0.05)",
                padding: "3px",
                borderRadius: "8px",
                border: "1px solid rgba(255, 255, 255, 0.1)",
              }}
            >
              <button
                type="button"
                onClick={() => setViewMode("grid")}
                style={{
                  backgroundColor: viewMode === "grid" ? "var(--accent-primary)" : "transparent",
                  color: viewMode === "grid" ? "#ffffff" : "var(--text-muted)",
                  border: "none",
                  borderRadius: "6px",
                  padding: "0.35rem 0.65rem",
                  cursor: "pointer",
                  display: "flex",
                  alignItems: "center",
                  gap: "0.35rem",
                  fontSize: "0.85rem",
                  fontWeight: "600",
                  transition: "all 0.2s ease",
                }}
                title="Hiển thị dạng Card nhiều cột"
              >
                <Grid size={16} /> Grid Card
              </button>
              <button
                type="button"
                onClick={() => setViewMode("table")}
                style={{
                  backgroundColor: viewMode === "table" ? "var(--accent-primary)" : "transparent",
                  color: viewMode === "table" ? "#ffffff" : "var(--text-muted)",
                  border: "none",
                  borderRadius: "6px",
                  padding: "0.35rem 0.65rem",
                  cursor: "pointer",
                  display: "flex",
                  alignItems: "center",
                  gap: "0.35rem",
                  fontSize: "0.85rem",
                  fontWeight: "600",
                  transition: "all 0.2s ease",
                }}
                title="Hiển thị dạng Bảng"
              >
                <List size={16} /> Bảng
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Main Student Content */}
      {loading ? (
        <div className="glass-panel" style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
          Đang nạp danh sách học sinh từ Realtime Cloud...
        </div>
      ) : filteredStudents.length === 0 ? (
        <div className="glass-panel" style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
          Không tìm thấy học sinh nào phù hợp.
        </div>
      ) : viewMode === "grid" ? (
        /* Multi-column Grid Cards View */
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fill, minmax(310px, 1fr))",
            gap: "1.25rem",
          }}
        >
          {filteredStudents.map((hs) => {
            const isInactive = hs.trang_thai === "DA_NGHI" || hs.trang_thai === "NGHI_HOC";
            const phone = hs.sdt_phu_huynh || hs.sdt || "";

            return (
              <div
                key={hs._key}
                className="glass-panel"
                style={{
                  display: "flex",
                  flexDirection: "column",
                  justifyContent: "space-between",
                  padding: "1.25rem",
                  borderRadius: "14px",
                  transition: "transform 0.2s ease, box-shadow 0.2s ease",
                  position: "relative",
                }}
              >
                <div>
                  {/* Card Top Header */}
                  <div
                    style={{
                      display: "flex",
                      alignItems: "flex-start",
                      justifyContent: "space-between",
                      gap: "0.75rem",
                      marginBottom: "1rem",
                    }}
                  >
                    <div style={{ display: "flex", alignItems: "center", gap: "0.85rem" }}>
                      <div
                        style={{
                          width: "48px",
                          height: "48px",
                          borderRadius: "14px",
                          background: "linear-gradient(135deg, rgba(13, 148, 136, 0.25), rgba(99, 102, 241, 0.25))",
                          color: "var(--accent-primary)",
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                          fontWeight: "700",
                          fontSize: "1.2rem",
                          boxShadow: "0 4px 12px rgba(0,0,0,0.15)",
                          border: "1px solid rgba(13, 148, 136, 0.3)",
                          flexShrink: 0,
                        }}
                      >
                        {hs.ten ? hs.ten.charAt(0).toUpperCase() : "H"}
                      </div>
                      <div>
                        <Link
                          href={`/hoc-sinh/${hs.id || hs._key}`}
                          style={{
                            color: "var(--text-primary)",
                            fontWeight: "700",
                            fontSize: "1.05rem",
                            textDecoration: "none",
                            display: "block",
                          }}
                          className="hover-underline"
                        >
                          {hs.ten || "Chưa nhập tên"}
                        </Link>
                        <span
                          style={{
                            fontSize: "0.75rem",
                            color: "var(--text-muted)",
                            backgroundColor: "rgba(255, 255, 255, 0.05)",
                            padding: "0.15rem 0.45rem",
                            borderRadius: "6px",
                            display: "inline-block",
                            marginTop: "0.2rem",
                          }}
                        >
                          ID: #{hs.id || hs._key}
                        </span>
                      </div>
                    </div>

                    <span
                      style={{
                        fontSize: "0.72rem",
                        fontWeight: "600",
                        padding: "0.25rem 0.65rem",
                        borderRadius: "20px",
                        backgroundColor: isInactive ? "rgba(239, 68, 68, 0.15)" : "rgba(34, 197, 94, 0.15)",
                        color: isInactive ? "#ef4444" : "#22c55e",
                        border: isInactive
                          ? "1px solid rgba(239, 68, 68, 0.3)"
                          : "1px solid rgba(34, 197, 94, 0.3)",
                        whiteSpace: "nowrap",
                      }}
                    >
                      {isInactive ? "Đã nghỉ" : "Đang học"}
                    </span>
                  </div>

                  {/* Information Details */}
                  <div
                    style={{
                      display: "flex",
                      flexDirection: "column",
                      gap: "0.65rem",
                      fontSize: "0.88rem",
                      marginBottom: "1.25rem",
                      color: "var(--text-secondary)",
                    }}
                  >
                    {/* School */}
                    <div style={{ display: "flex", alignItems: "center", gap: "0.55rem" }}>
                      <GraduationCap size={16} style={{ color: "var(--accent-primary)", flexShrink: 0 }} />
                      <span
                        style={{
                          overflow: "hidden",
                          textOverflow: "ellipsis",
                          whiteSpace: "nowrap",
                          color: getSchoolName(hs) ? "var(--text-primary)" : "var(--text-muted)",
                        }}
                      >
                        {getSchoolName(hs) || "Chưa cập nhật trường"}
                      </span>
                    </div>

                    {/* Parent Phone & Zalo Trigger */}
                    <div
                      style={{
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "space-between",
                        flexWrap: "wrap",
                        gap: "0.5rem",
                      }}
                    >
                      <div style={{ display: "flex", alignItems: "center", gap: "0.55rem" }}>
                        <Phone size={16} style={{ color: "#3b82f6", flexShrink: 0 }} />
                        {phone ? (
                          <a
                            href={`tel:${phone}`}
                            style={{ color: "var(--text-primary)", fontWeight: "600", textDecoration: "none" }}
                          >
                            {phone}
                          </a>
                        ) : (
                          <span style={{ color: "var(--text-muted)" }}>--</span>
                        )}
                      </div>

                      {phone && (
                        <button
                          type="button"
                          onClick={() => {
                            const clean = phone.replace(/[^0-9]/g, "");
                            if (clean) {
                              window.location.href = `zalo://chat?phone=${clean}`;
                              setTimeout(() => {
                                window.open(`https://zalo.me/${clean}`, "_blank");
                              }, 600);
                            }
                          }}
                          style={{
                            backgroundColor: "#0068ff",
                            color: "#ffffff",
                            border: "none",
                            borderRadius: "6px",
                            padding: "0.25rem 0.6rem",
                            fontSize: "0.75rem",
                            fontWeight: "600",
                            cursor: "pointer",
                            display: "inline-flex",
                            alignItems: "center",
                            gap: "0.3rem",
                            boxShadow: "0 2px 6px rgba(0,104,255,0.25)",
                          }}
                          title="Mở ứng dụng Zalo PC"
                        >
                          <MessageCircle size={12} /> Zalo PC
                        </button>
                      )}
                    </div>

                    {/* Note Snippet */}
                    {hs.ghi_chu && (
                      <div
                        style={{
                          fontSize: "0.8rem",
                          color: "var(--text-muted)",
                          backgroundColor: "rgba(255, 255, 255, 0.03)",
                          padding: "0.5rem 0.75rem",
                          borderRadius: "8px",
                          borderLeft: "3px solid var(--accent-primary)",
                          marginTop: "0.2rem",
                        }}
                      >
                        {hs.ghi_chu}
                      </div>
                    )}
                  </div>
                </div>

                {/* Card Action Buttons */}
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: "0.5rem",
                    paddingTop: "0.85rem",
                    borderTop: "1px solid rgba(255, 255, 255, 0.08)",
                  }}
                >
                  <Link
                    href={`/hoc-sinh/${hs.id || hs._key}`}
                    className="btn-secondary"
                    style={{
                      flex: 1,
                      justifyContent: "center",
                      fontSize: "0.82rem",
                      padding: "0.45rem 0.6rem",
                      display: "inline-flex",
                      alignItems: "center",
                      gap: "0.35rem",
                      textDecoration: "none",
                    }}
                  >
                    <Eye size={14} /> Hồ sơ
                  </Link>

                  <button
                    type="button"
                    onClick={() => setQrStudent(hs)}
                    className="btn-secondary"
                    style={{
                      fontSize: "0.82rem",
                      padding: "0.45rem 0.65rem",
                      display: "inline-flex",
                      alignItems: "center",
                      gap: "0.25rem",
                      color: "var(--accent-primary)",
                      borderColor: "rgba(13, 148, 136, 0.3)",
                    }}
                    title="Xem mã QR Thẻ học sinh"
                  >
                    <QrCode size={14} /> Mã QR
                  </button>
                  <button
                    onClick={() => handleOpenModal(hs)}
                    className="btn-secondary"
                    style={{
                      fontSize: "0.82rem",
                      padding: "0.45rem 0.65rem",
                      display: "inline-flex",
                      alignItems: "center",
                      gap: "0.25rem",
                    }}
                    title="Chỉnh sửa thông tin"
                  >
                    <Edit size={14} /> Sửa
                  </button>
                  <button
                    onClick={() => handleDelete(hs._key)}
                    className="btn-secondary"
                    style={{
                      fontSize: "0.82rem",
                      padding: "0.45rem 0.65rem",
                      color: "var(--danger)",
                      borderColor: "rgba(239, 68, 68, 0.3)",
                      display: "inline-flex",
                      alignItems: "center",
                    }}
                    title="Xóa học sinh"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        /* Fallback Table View */
        <div className="glass-panel" style={{ overflow: "hidden" }}>
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Họ & Tên Học Sinh</th>
                  <th>SĐT Phụ Huynh</th>
                  <th>Trường Học</th>
                  <th>Ghi Chú</th>
                  <th style={{ textAlign: "right" }}>Thao Tác</th>
                </tr>
              </thead>
              <tbody>
                {filteredStudents.map((hs) => (
                  <tr key={hs._key}>
                    <td style={{ fontWeight: "600" }}>
                      <div style={{ display: "flex", alignItems: "center", gap: "0.75rem" }}>
                        <div
                          style={{
                            width: "36px",
                            height: "36px",
                            borderRadius: "50%",
                            backgroundColor: "rgba(13, 148, 136, 0.15)",
                            color: "var(--accent-primary)",
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "center",
                            fontWeight: "700",
                            fontSize: "0.9rem",
                          }}
                        >
                          {hs.ten ? hs.ten.charAt(0).toUpperCase() : "H"}
                        </div>
                        <div>
                          <Link
                            href={`/hoc-sinh/${hs.id || hs._key}`}
                            style={{ color: "var(--text-primary)", fontWeight: "600", textDecoration: "none" }}
                            className="hover-underline"
                          >
                            {hs.ten || "Chưa nhập tên"}
                          </Link>
                          <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>
                            ID: #{hs.id || hs._key}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td>
                      {hs.sdt_phu_huynh || hs.sdt ? (
                        <div style={{ display: "flex", gap: "0.4rem", alignItems: "center" }}>
                          <a
                            href={`tel:${hs.sdt_phu_huynh || hs.sdt}`}
                            style={{
                              color: "var(--accent-primary)",
                              textDecoration: "none",
                              display: "inline-flex",
                              alignItems: "center",
                              gap: "0.25rem",
                            }}
                          >
                            <Phone size={14} /> {hs.sdt_phu_huynh || hs.sdt}
                          </a>
                          <button
                            type="button"
                            onClick={() => {
                              const clean = (hs.sdt_phu_huynh || hs.sdt || "").replace(/[^0-9]/g, "");
                              if (clean) {
                                window.location.href = `zalo://chat?phone=${clean}`;
                                setTimeout(() => {
                                  window.open(`https://zalo.me/${clean}`, "_blank");
                                }, 600);
                              }
                            }}
                            style={{
                              backgroundColor: "#0068ff",
                              color: "#ffffff",
                              border: "none",
                              borderRadius: "4px",
                              padding: "0.25rem 0.45rem",
                              fontSize: "0.75rem",
                              fontWeight: "600",
                              cursor: "pointer",
                            }}
                            title="Mở ứng dụng Zalo PC"
                          >
                            Zalo PC
                          </button>
                        </div>
                      ) : (
                        <span style={{ color: "var(--text-muted)" }}>--</span>
                      )}
                    </td>
                    <td>{getSchoolName(hs) || "--"}</td>
                    <td style={{ fontSize: "0.85rem", color: "var(--text-secondary)" }}>{hs.ghi_chu || "--"}</td>
                    <td style={{ textAlign: "right" }}>
                      <Link
                        href={`/hoc-sinh/${hs.id || hs._key}`}
                        className="btn-secondary"
                        style={{
                          padding: "0.4rem 0.65rem",
                          marginRight: "0.5rem",
                          display: "inline-flex",
                          alignItems: "center",
                        }}
                        title="Xem chi tiết hồ sơ"
                      >
                        <Eye size={14} />
                      </Link>
                      <button
                        onClick={() => handleOpenModal(hs)}
                        className="btn-secondary"
                        style={{ padding: "0.4rem 0.65rem", marginRight: "0.5rem" }}
                        title="Chỉnh sửa"
                      >
                        <Edit size={14} />
                      </button>
                      <button
                        onClick={() => handleDelete(hs._key)}
                        className="btn-secondary"
                        style={{
                          padding: "0.4rem 0.65rem",
                          color: "var(--danger)",
                          borderColor: "rgba(239, 68, 68, 0.3)",
                        }}
                        title="Xóa"
                      >
                        <Trash2 size={14} />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Modal Dialog Add / Edit Student */}
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
          <div
            className="glass-panel"
            style={{ width: "100%", maxWidth: "500px", padding: "1.75rem", backgroundColor: "var(--bg-secondary)" }}
          >
            <h3 style={{ fontSize: "1.25rem", fontWeight: "700", marginBottom: "1.25rem" }}>
              {editingHs ? "Chỉnh Sửa Thông Tin Học Sinh" : "Thêm Học Sinh Mới"}
            </h3>

            <form onSubmit={handleSave} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Họ và tên học sinh *
                </label>
                <input
                  type="text"
                  required
                  placeholder="Ví dụ: Nguyễn Văn An"
                  value={formData.ten}
                  onChange={(e) => setFormData({ ...formData, ten: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Số điện thoại phụ huynh
                </label>
                <input
                  type="text"
                  placeholder="Ví dụ: 0987654321"
                  value={formData.sdt_phu_huynh}
                  onChange={(e) => setFormData({ ...formData, sdt_phu_huynh: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Trường học
                </label>
                <input
                  type="text"
                  placeholder="Ví dụ: THPT Lê Hồng Phong"
                  value={formData.truong}
                  onChange={(e) => setFormData({ ...formData, truong: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Ghi chú
                </label>
                <textarea
                  rows={3}
                  placeholder="Ghi chú về học lực, miễn giảm..."
                  value={formData.ghi_chu}
                  onChange={(e) => setFormData({ ...formData, ghi_chu: e.target.value })}
                  className="input-control"
                  style={{ width: "100%", resize: "vertical" }}
                />
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "1rem" }}>
                <button type="button" onClick={() => setShowModal(false)} className="btn-secondary">
                  Hủy
                </button>
                <button type="submit" className="btn-primary">
                  {editingHs ? "Cập Nhật" : "Tạo Mới"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* STUDENT QR CODE MODAL */}
      {qrStudent && (
        <StudentQRModal student={qrStudent} onClose={() => setQrStudent(null)} />
      )}
    </div>
  );
}
