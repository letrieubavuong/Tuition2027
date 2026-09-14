"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { db, ref, onValue, set, remove } from "@/lib/firebase";
import Link from "next/link";
import {
  ArrowLeft,
  Users,
  Calendar,
  CheckSquare,
  MessageSquare,
  Plus,
  Trash2,
  Phone,
  Clock,
  UserPlus
} from "lucide-react";

export default function LopDetailContainer() {
  const params = useParams();
  const router = useRouter();
  const classId = params.id;

  const [classInfo, setClassInfo] = useState(null);
  const [activeTab, setActiveTab] = useState("students");
  const [loading, setLoading] = useState(true);

  // Data states
  const [classStudents, setClassStudents] = useState([]);
  const [allStudents, setAllStudents] = useState([]);
  const [schedules, setSchedules] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [evaluations, setEvaluations] = useState([]);

  // Modals state
  const [showAddStudentModal, setShowAddStudentModal] = useState(false);
  const [showAddScheduleModal, setShowAddScheduleModal] = useState(false);
  const [showAddTaskModal, setShowAddTaskModal] = useState(false);

  // Form states
  const [selectedStudentId, setSelectedStudentId] = useState("");
  const [scheduleForm, setScheduleForm] = useState({
    thuTrongTuan: 2,
    gioBatDau: "17:30",
    gioKetThuc: "19:00",
  });
  const [taskForm, setTaskForm] = useState({
    ten_nhiem_vu: "",
    mo_ta: "",
    han_nop: "",
  });

  useEffect(() => {
    if (!classId) return;

    // 1. Fetch Class Info
    const lopRef = ref(db, `lop/${classId}`);
    const unsubLop = onValue(lopRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        setClassInfo(val);
      }
    });

    // 2. Fetch All Students (for name mapping & add modal)
    const hsRef = ref(db, "hoc_sinh");
    const unsubHs = onValue(hsRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        setAllStudents(list);
      }
    });

    // 3. Fetch Class-Student Roster (lop_hoc_sinh)
    const lhsRef = ref(db, "lop_hoc_sinh");
    const unsubLhs = onValue(lhsRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        const filtered = list.filter((lhs) => String(lhs.id_lop) === String(classId));
        setClassStudents(filtered);
      } else {
        setClassStudents([]);
      }
      setLoading(false);
    });

    // 4. Fetch Schedules (lich_hoc)
    const lhRef = ref(db, "lich_hoc");
    const unsubLh = onValue(lhRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        const filtered = list.filter((lh) => String(lh.id_lop) === String(classId));
        setSchedules(filtered);
      } else {
        setSchedules([]);
      }
    });

    // 5. Fetch Tasks (nhiem_vu)
    const nvRef = ref(db, "nhiem_vu");
    const unsubNv = onValue(nvRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        const filtered = list.filter((nv) => String(nv.id_lop) === String(classId));
        setTasks(filtered);
      } else {
        setTasks([]);
      }
    });

    return () => {
      unsubLop();
      unsubHs();
      unsubLhs();
      unsubLh();
      unsubNv();
    };
  }, [classId]);

  // Handlers for Add Student to Class
  const handleAddStudentToClass = async (e) => {
    e.preventDefault();
    if (!selectedStudentId) return;

    try {
      const key = `${selectedStudentId}_${classId}`;
      await set(ref(db, `lop_hoc_sinh/${key}`), {
        id_hoc_sinh: Number(selectedStudentId),
        id_lop: Number(classId),
        created_at: new Date().toISOString(),
      });
      setShowAddStudentModal(false);
      setSelectedStudentId("");
    } catch (err) {
      alert("Lỗi thêm học sinh vào lớp: " + err.message);
    }
  };

  const handleRemoveStudentFromClass = async (hsId) => {
    if (confirm("Xóa học sinh này khỏi lớp?")) {
      try {
        const key = `${hsId}_${classId}`;
        await remove(ref(db, `lop_hoc_sinh/${key}`));
      } catch (err) {
        alert("Lỗi xóa học sinh khỏi lớp: " + err.message);
      }
    }
  };

  // Handler Add Schedule Slot
  const handleAddSchedule = async (e) => {
    e.preventDefault();
    try {
      const id = Date.now();
      await set(ref(db, `lich_hoc/${id}`), {
        id: id,
        id_lop: Number(classId),
        thuTrongTuan: Number(scheduleForm.thuTrongTuan),
        gioBatDau: scheduleForm.gioBatDau,
        gioKetThuc: scheduleForm.gioKetThuc,
      });
      setShowAddScheduleModal(false);
    } catch (err) {
      alert("Lỗi thêm lịch học: " + err.message);
    }
  };

  const handleDeleteSchedule = async (schedId) => {
    if (confirm("Xóa ca học này?")) {
      try {
        await remove(ref(db, `lich_hoc/${schedId}`));
      } catch (err) {
        alert("Lỗi xóa ca học: " + err.message);
      }
    }
  };

  // Handler Add Task
  const handleAddTask = async (e) => {
    e.preventDefault();
    if (!taskForm.ten_nhiem_vu.trim()) return;

    try {
      const id = Date.now();
      await set(ref(db, `nhiem_vu/${id}`), {
        id: id,
        id_lop: Number(classId),
        ten_nhiem_vu: taskForm.ten_nhiem_vu,
        mo_ta: taskForm.mo_ta,
        han_nop: taskForm.han_nop,
        trang_thai: "Chưa hoàn thành",
        created_at: new Date().toISOString(),
      });
      setShowAddTaskModal(false);
      setTaskForm({ ten_nhiem_vu: "", mo_ta: "", han_nop: "" });
    } catch (err) {
      alert("Lỗi tạo bài tập: " + err.message);
    }
  };

  const handleDeleteTask = async (taskId) => {
    if (confirm("Xóa bài tập này?")) {
      try {
        await remove(ref(db, `nhiem_vu/${taskId}`));
      } catch (err) {
        alert("Lỗi xóa bài tập: " + err.message);
      }
    }
  };

  const formatCurrency = (num) => {
    return new Intl.NumberFormat("vi-VN", { style: "currency", currency: "VND" }).format(num || 0);
  };

  const getDayName = (thu) => {
    switch (Number(thu)) {
      case 2: return "Thứ 2";
      case 3: return "Thứ 3";
      case 4: return "Thứ 4";
      case 5: return "Thứ 5";
      case 6: return "Thứ 6";
      case 7: return "Thứ 7";
      case 1:
      case 8: return "Chủ Nhật";
      default: return `Thứ ${thu}`;
    }
  };

  return (
    <div>
      {/* Back Button & Header */}
      <div style={{ marginBottom: "1.5rem" }}>
        <Link href="/lop-hoc" className="btn-secondary" style={{ marginBottom: "1rem" }}>
          <ArrowLeft size={16} /> Quay lại danh sách lớp
        </Link>

        <div className="glass-panel" style={{ padding: "1.5rem", display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "1rem" }}>
          <div>
            <span className="badge badge-info" style={{ marginBottom: "0.5rem" }}>
              Khối {classInfo?.khoi || "..."}
            </span>
            <h2 style={{ fontSize: "1.8rem", fontWeight: "800" }}>{classInfo?.ten || `Lớp học #${classId}`}</h2>
            <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem", marginTop: "0.25rem" }}>
              {classInfo?.mo_ta || "Chưa có mô tả chi tiết."}
            </p>
          </div>

          <div style={{ textAlign: "right" }}>
            <span style={{ fontSize: "0.85rem", color: "var(--text-muted)", display: "block" }}>Học phí / Buổi:</span>
            <span style={{ fontSize: "1.3rem", fontWeight: "800", color: "var(--accent-primary)" }}>
              {formatCurrency(classInfo?.hoc_phi_buoi || 0)}
            </span>
          </div>
        </div>
      </div>

      {/* Tabs Menu */}
      <div style={{ display: "flex", gap: "0.5rem", marginBottom: "1.5rem", borderBottom: "1px solid var(--border-color)", paddingBottom: "0.5rem", overflowX: "auto" }}>
        <button
          onClick={() => setActiveTab("students")}
          className={activeTab === "students" ? "btn-primary" : "btn-secondary"}
          style={{ fontSize: "0.9rem", padding: "0.6rem 1.2rem" }}
        >
          <Users size={16} /> Danh Sách Học Sinh ({classStudents.length})
        </button>
        <button
          onClick={() => setActiveTab("schedule")}
          className={activeTab === "schedule" ? "btn-primary" : "btn-secondary"}
          style={{ fontSize: "0.9rem", padding: "0.6rem 1.2rem" }}
        >
          <Calendar size={16} /> Lịch Học ({schedules.length})
        </button>
        <button
          onClick={() => setActiveTab("tasks")}
          className={activeTab === "tasks" ? "btn-primary" : "btn-secondary"}
          style={{ fontSize: "0.9rem", padding: "0.6rem 1.2rem" }}
        >
          <CheckSquare size={16} /> Bài Tập & Nhiệm Vụ ({tasks.length})
        </button>
      </div>

      {/* TAB 1: DANH SÁCH HỌC SINH */}
      {activeTab === "students" && (
        <div>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem" }}>
            <h3 style={{ fontSize: "1.1rem", fontWeight: "700" }}>Học Sinh Trong Lớp</h3>
            <button onClick={() => setShowAddStudentModal(true)} className="btn-primary" style={{ padding: "0.5rem 1rem", fontSize: "0.85rem" }}>
              <UserPlus size={16} /> Thêm Học Sinh Vào Lớp
            </button>
          </div>

          <div className="glass-panel" style={{ overflow: "hidden" }}>
            {classStudents.length === 0 ? (
              <div style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
                Lớp học này chưa có học sinh nào. Bấm nút "Thêm Học Sinh Vào Lớp" để xếp lớp.
              </div>
            ) : (
              <div className="data-table-container">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Tên Học Sinh</th>
                      <th>Trạng Thái</th>
                      <th>SĐT Phụ Huynh / Zalo</th>
                      <th>Trường Học</th>
                      <th style={{ textAlign: "right" }}>Thao Tác</th>
                    </tr>
                  </thead>
                  <tbody>
                    {classStudents.map((lhs) => {
                      const student = allStudents.find((s) => String(s.id) === String(lhs.id_hoc_sinh) || String(s._key) === String(lhs.id_hoc_sinh)) || {};
                      const phone = student.sdt_phu_huynh || student.sdt || "";
                      const cleanPhone = phone.replace(/[^0-9]/g, "");
                      const status = lhs.trang_thai || "DANG_HOC";

                      return (
                        <tr key={lhs.id_hoc_sinh || lhs._key}>
                          <td style={{ fontWeight: "700" }}>
                            <Link href={`/hoc-sinh/${student.id || student._key || lhs.id_hoc_sinh}`} style={{ color: "var(--text-primary)", textDecoration: "none" }}>
                              {student.ten || `Học sinh #${lhs.id_hoc_sinh}`}
                            </Link>
                          </td>
                          <td>
                            {status === "DANG_HOC" ? (
                              <span className="badge badge-success">Đang học</span>
                            ) : status === "TAM_NGHI" ? (
                              <span className="badge badge-warning">Tạm nghỉ</span>
                            ) : (
                              <span className="badge" style={{ backgroundColor: "rgba(239,68,68,0.2)", color: "var(--danger)" }}>
                                Đã nghỉ
                              </span>
                            )}
                          </td>
                          <td>
                            {phone ? (
                              <div style={{ display: "flex", gap: "0.4rem", alignItems: "center" }}>
                                <a href={`tel:${phone}`} style={{ color: "var(--accent-primary)", textDecoration: "none", display: "inline-flex", alignItems: "center", gap: "0.25rem" }}>
                                  <Phone size={14} /> {phone}
                                </a>
                                {cleanPhone && (
                                  <button
                                    type="button"
                                    onClick={() => {
                                      window.location.href = `zalo://chat?phone=${cleanPhone}`;
                                      setTimeout(() => {
                                        window.open(`https://zalo.me/${cleanPhone}`, "_blank");
                                      }, 600);
                                    }}
                                    style={{
                                      backgroundColor: "#0068ff",
                                      color: "#fff",
                                      border: "none",
                                      borderRadius: "4px",
                                      padding: "0.2rem 0.4rem",
                                      fontSize: "0.75rem",
                                      fontWeight: "600",
                                      cursor: "pointer",
                                    }}
                                    title="Mở ứng dụng Zalo PC"
                                  >
                                    Zalo PC
                                  </button>
                                )}
                              </div>
                            ) : (
                              "--"
                            )}
                          </td>
                          <td>{student.truong_dang_hoc || student.truong || student.ten_truong || "--"}</td>
                          <td style={{ textAlign: "right" }}>
                            {status !== "TAM_NGHI" ? (
                              <button
                                onClick={async () => {
                                  const key = lhs._key || `${lhs.id_hoc_sinh}_${classId}`;
                                  await set(ref(db, `lop_hoc_sinh/${key}/trang_thai`), "TAM_NGHI");
                                }}
                                className="btn-secondary"
                                style={{ padding: "0.35rem 0.65rem", marginRight: "0.4rem", color: "var(--warning)" }}
                                title="Cho học sinh tạm nghỉ"
                              >
                                Tạm nghỉ
                              </button>
                            ) : (
                              <button
                                onClick={async () => {
                                  const key = lhs._key || `${lhs.id_hoc_sinh}_${classId}`;
                                  await set(ref(db, `lop_hoc_sinh/${key}/trang_thai`), "DANG_HOC");
                                }}
                                className="btn-secondary"
                                style={{ padding: "0.35rem 0.65rem", marginRight: "0.4rem", color: "var(--success)" }}
                                title="Học sinh đi học lại"
                              >
                                Học lại
                              </button>
                            )}

                            <button
                              onClick={() => handleRemoveStudentFromClass(lhs.id_hoc_sinh)}
                              className="btn-secondary"
                              style={{ padding: "0.35rem 0.65rem", color: "var(--danger)", borderColor: "rgba(239, 68, 68, 0.3)" }}
                              title="Loại khỏi lớp"
                            >
                              <Trash2 size={14} />
                            </button>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}

      {/* TAB 2: LỊCH HỌC */}
      {activeTab === "schedule" && (
        <div>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem" }}>
            <h3 style={{ fontSize: "1.1rem", fontWeight: "700" }}>Lịch Dạy & Ca Học Trong Tuần</h3>
            <button onClick={() => setShowAddScheduleModal(true)} className="btn-primary" style={{ padding: "0.5rem 1rem", fontSize: "0.85rem" }}>
              <Plus size={16} /> Thêm Ca Học Mới
            </button>
          </div>

          {schedules.length === 0 ? (
            <div className="glass-panel" style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
              Chưa có lịch dạy nào được xếp cho lớp này.
            </div>
          ) : (
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))", gap: "1rem" }}>
              {schedules.map((s) => (
                <div key={s.id} className="glass-card" style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <div>
                    <span className="badge badge-success" style={{ marginBottom: "0.5rem" }}>
                      {getDayName(s.thuTrongTuan)}
                    </span>
                    <div style={{ fontSize: "1.1rem", fontWeight: "700", display: "flex", alignItems: "center", gap: "0.4rem" }}>
                      <Clock size={16} color="var(--accent-primary)" /> {s.gioBatDau} - {s.gioKetThuc}
                    </div>
                  </div>
                  <button
                    onClick={() => handleDeleteSchedule(s.id)}
                    className="btn-secondary"
                    style={{ padding: "0.4rem 0.6rem", color: "var(--danger)" }}
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* TAB 3: BÀI TẬP & NHIỆM VỤ */}
      {activeTab === "tasks" && (
        <div>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem" }}>
            <h3 style={{ fontSize: "1.1rem", fontWeight: "700" }}>Bài Tập & Nhiệm Vụ Cho Lớp</h3>
            <button onClick={() => setShowAddTaskModal(true)} className="btn-primary" style={{ padding: "0.5rem 1rem", fontSize: "0.85rem" }}>
              <Plus size={16} /> Giao Bài Tập Mới
            </button>
          </div>

          {tasks.length === 0 ? (
            <div className="glass-panel" style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
              Chưa có bài tập nào được giao cho lớp này.
            </div>
          ) : (
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(320px, 1fr))", gap: "1rem" }}>
              {tasks.map((t) => (
                <div key={t.id} className="glass-card">
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "0.5rem" }}>
                    <h4 style={{ fontSize: "1.1rem", fontWeight: "700" }}>{t.ten_nhiem_vu}</h4>
                    <button onClick={() => handleDeleteTask(t.id)} className="btn-secondary" style={{ padding: "0.3rem 0.5rem", color: "var(--danger)" }}>
                      <Trash2 size={14} />
                    </button>
                  </div>
                  <p style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginBottom: "0.75rem" }}>{t.mo_ta || "Chưa có mô tả chi tiết."}</p>
                  {t.han_nop && (
                    <span className="badge badge-warning" style={{ fontSize: "0.75rem" }}>
                      Hạn nộp: {t.han_nop}
                    </span>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* MODAL: Thêm học sinh vào lớp */}
      {showAddStudentModal && (
        <div style={{ position: "fixed", inset: 0, backgroundColor: "rgba(0, 0, 0, 0.6)", backdropFilter: "blur(4px)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100, padding: "1rem" }}>
          <div className="glass-panel" style={{ width: "100%", maxWidth: "440px", padding: "1.5rem", backgroundColor: "var(--bg-secondary)" }}>
            <h3 style={{ fontSize: "1.2rem", fontWeight: "700", marginBottom: "1rem" }}>Thêm Học Sinh Vào Lớp</h3>
            <form onSubmit={handleAddStudentToClass}>
              <div style={{ marginBottom: "1.25rem" }}>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>Chọn học sinh từ danh sách:</label>
                <select
                  required
                  value={selectedStudentId}
                  onChange={(e) => setSelectedStudentId(e.target.value)}
                  className="input-control"
                  style={{ width: "100%" }}
                >
                  <option value="">-- Chọn học sinh --</option>
                  {allStudents.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.ten} (SĐT: {s.sdt_phu_huynh || s.sdt || "Không có"})
                    </option>
                  ))}
                </select>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem" }}>
                <button type="button" onClick={() => setShowAddStudentModal(false)} className="btn-secondary">Hủy</button>
                <button type="submit" className="btn-primary">Thêm Vào Lớp</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: Thêm ca học mới */}
      {showAddScheduleModal && (
        <div style={{ position: "fixed", inset: 0, backgroundColor: "rgba(0, 0, 0, 0.6)", backdropFilter: "blur(4px)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100, padding: "1rem" }}>
          <div className="glass-panel" style={{ width: "100%", maxWidth: "440px", padding: "1.5rem", backgroundColor: "var(--bg-secondary)" }}>
            <h3 style={{ fontSize: "1.2rem", fontWeight: "700", marginBottom: "1rem" }}>Thêm Ca Học Cho Lớp</h3>
            <form onSubmit={handleAddSchedule} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>Thứ trong tuần:</label>
                <select
                  value={scheduleForm.thuTrongTuan}
                  onChange={(e) => setScheduleForm({ ...scheduleForm, thuTrongTuan: Number(e.target.value) })}
                  className="input-control"
                  style={{ width: "100%" }}
                >
                  <option value={2}>Thứ 2</option>
                  <option value={3}>Thứ 3</option>
                  <option value={4}>Thứ 4</option>
                  <option value={5}>Thứ 5</option>
                  <option value={6}>Thứ 6</option>
                  <option value={7}>Thứ 7</option>
                  <option value={8}>Chủ Nhật</option>
                </select>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem" }}>
                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>Giờ bắt đầu:</label>
                  <input
                    type="time"
                    value={scheduleForm.gioBatDau}
                    onChange={(e) => setScheduleForm({ ...scheduleForm, gioBatDau: e.target.value })}
                    className="input-control"
                    style={{ width: "100%" }}
                  />
                </div>
                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>Giờ kết thúc:</label>
                  <input
                    type="time"
                    value={scheduleForm.gioKetThuc}
                    onChange={(e) => setScheduleForm({ ...scheduleForm, gioKetThuc: e.target.value })}
                    className="input-control"
                    style={{ width: "100%" }}
                  />
                </div>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "1rem" }}>
                <button type="button" onClick={() => setShowAddScheduleModal(false)} className="btn-secondary">Hủy</button>
                <button type="submit" className="btn-primary">Thêm Ca Học</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: Giao bài tập mới */}
      {showAddTaskModal && (
        <div style={{ position: "fixed", inset: 0, backgroundColor: "rgba(0, 0, 0, 0.6)", backdropFilter: "blur(4px)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100, padding: "1rem" }}>
          <div className="glass-panel" style={{ width: "100%", maxWidth: "440px", padding: "1.5rem", backgroundColor: "var(--bg-secondary)" }}>
            <h3 style={{ fontSize: "1.2rem", fontWeight: "700", marginBottom: "1rem" }}>Giao Bài Tập Mới</h3>
            <form onSubmit={handleAddTask} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>Tên bài tập / Nhiệm vụ *</label>
                <input
                  type="text"
                  required
                  placeholder="Ví dụ: Làm bài tập 1, 2 trang 45"
                  value={taskForm.ten_nhiem_vu}
                  onChange={(e) => setTaskForm({ ...taskForm, ten_nhiem_vu: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>Hạn nộp (nếu có):</label>
                <input
                  type="date"
                  value={taskForm.han_nop}
                  onChange={(e) => setTaskForm({ ...taskForm, han_nop: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>Mô tả chi tiết:</label>
                <textarea
                  rows={3}
                  value={taskForm.mo_ta}
                  onChange={(e) => setTaskForm({ ...taskForm, mo_ta: e.target.value })}
                  className="input-control"
                  style={{ width: "100%", resize: "vertical" }}
                />
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "1rem" }}>
                <button type="button" onClick={() => setShowAddTaskModal(false)} className="btn-secondary">Hủy</button>
                <button type="submit" className="btn-primary">Giao Bài Tập</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
