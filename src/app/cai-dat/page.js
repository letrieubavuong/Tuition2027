"use client";

import { useEffect, useState } from "react";
import { db, ref, onValue, set, remove, get } from "@/lib/firebase";
import {
  Settings,
  CreditCard,
  Building2,
  UserCheck,
  CheckCircle,
  Save,
  RefreshCw,
  BookOpen,
  Award,
  HelpCircle,
  Plus,
  Trash2,
  Edit,
  Cloud,
  CloudUpload,
  CloudDownload,
  Calculator,
  Bell,
  FileSpreadsheet,
  Code,
  DollarSign,
  FileText,
  School,
  X,
} from "lucide-react";

export default function CaiDatPage() {
  // Manager & Tuition Fee State
  const [managerConfig, setManagerConfig] = useState({
    ten_quan_ly: "LÊ TRIỆU BÁ VƯƠNG",
    email: "bavuong@moet.edu.vn",
    hoc_phi_buoi: "50000",
    so_buoi_chuan_thang: "12",
    hoc_phi_thang: "600000",
  });

  // VietQR Bank Config State
  const [bankConfig, setBankConfig] = useState({
    ten_ngan_hang: "Sacombank",
    ma_bin: "970403",
    so_tai_khoan: "0905073175",
    ten_chu_tai_khoan: "LE TRIEU BA VUONG",
  });

  // Bonus Point Rules List State (CRUD)
  const [pointRules, setPointRules] = useState([
    { id: "co_mat", ten: "Có mặt đúng giờ", diem: 10, mo_ta: "Cộng điểm khi tham gia buổi học đúng giờ" },
    { id: "muon", ten: "Đi muộn / Trễ giờ", diem: 5, mo_ta: "Cộng điểm khuyến khích đi học dù muộn" },
    { id: "btvn_hoan_thanh", ten: "Hoàn thành bài tập về nhà", diem: 10, mo_ta: "Làm đầy đủ BTVN được giao" },
    { id: "kiem_tra_gioi", ten: "Bài kiểm tra điểm 10 / Xuất sắc", diem: 20, mo_ta: "Thưởng bài kiểm tra kết quả xuất sắc" },
    { id: "phat_bieu", ten: "Hăng hái phát biểu xây dựng bài", diem: 10, mo_ta: "Đóng góp ý kiến tích cực trong buổi học" },
  ]);

  // Schools List State (CRUD)
  const [schools, setSchools] = useState([]);

  // Automation & Cloud Sync Settings State
  const [systemSettings, setSystemSettings] = useState({
    auto_approve_payment: true,
    reminder_minutes: "10",
    google_sheets_url: "",
  });

  // Modal Controls
  const [showRuleModal, setShowRuleModal] = useState(false);
  const [editingRuleIndex, setEditingRuleIndex] = useState(null);
  const [ruleFormData, setRuleFormData] = useState({ ten: "", diem: 10, mo_ta: "" });

  const [showSchoolModal, setShowSchoolModal] = useState(false);
  const [editingSchool, setEditingSchool] = useState(null);
  const [schoolFormData, setSchoolFormData] = useState({ ten: "" });

  const [showScriptGuideModal, setShowScriptGuideModal] = useState(false);

  // Statuses
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [syncingSheets, setSyncingSheets] = useState(false);
  const [recalculating, setRecalculating] = useState(false);
  const [successMsg, setSuccessMsg] = useState("");
  const [errorMsg, setErrorMsg] = useState("");

  useEffect(() => {
    // 1. Load Manager & Tuition Settings
    const systemRef = ref(db, "cai_dat/he_thong");
    const unsubSystem = onValue(systemRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        setManagerConfig((prev) => ({ ...prev, ...val }));
        if (val.auto_approve_payment !== undefined || val.reminder_minutes !== undefined || val.google_sheets_url !== undefined) {
          setSystemSettings({
            auto_approve_payment: val.auto_approve_payment ?? true,
            reminder_minutes: val.reminder_minutes ?? "10",
            google_sheets_url: val.google_sheets_url ?? "",
          });
        }
      }
    });

    // 2. Load VietQR Bank Config
    const bankRef = ref(db, "cai_dat/bank");
    const unsubBank = onValue(bankRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        setBankConfig({
          ten_ngan_hang: val.ten_ngan_hang || val.bank_name || "Sacombank",
          ma_bin: val.ma_bin || val.bank_id || val.bin || "970403",
          so_tai_khoan: val.so_tai_khoan || val.account_no || "0905073175",
          ten_chu_tai_khoan: val.ten_chu_tai_khoan || val.account_name || "LE TRIEU BA VUONG",
        });
      }
    });

    // 3. Load Bonus Point Rules
    const rulesRef = ref(db, "cai_dat/quy_tac_diem");
    const unsubRules = onValue(rulesRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        if (Array.isArray(val)) {
          setPointRules(val.filter(Boolean));
        } else if (typeof val === "object") {
          const list = Object.entries(val).map(([k, item]) => ({
            id: item.id || k,
            ten: item.ten || item.ten_quy_tac || k,
            diem: item.diem ?? 10,
            mo_ta: item.mo_ta || "",
          }));
          setPointRules(list);
        }
      }
    });

    // 4. Load Schools
    const truongRef = ref(db, "truong");
    const unsubTruong = onValue(truongRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = [];
        if (Array.isArray(val)) {
          list = val.map((item, idx) => (item ? { ...item, _key: item.id || idx } : null)).filter(Boolean);
        } else if (typeof val === "object") {
          list = Object.entries(val).map(([k, item]) => ({
            ...item,
            _key: k,
          }));
        }
        setSchools(list);
      } else {
        setSchools([]);
      }
      setLoading(false);
    });

    return () => {
      unsubSystem();
      unsubBank();
      unsubRules();
      unsubTruong();
    };
  }, []);

  const showNotification = (msg, isError = false) => {
    if (isError) {
      setErrorMsg(msg);
      setTimeout(() => setErrorMsg(""), 5000);
    } else {
      setSuccessMsg(msg);
      setTimeout(() => setSuccessMsg(""), 4000);
    }
  };

  // --- SAVE GENERAL & BANK CONFIG ---
  const handleSaveGeneral = async (e) => {
    e.preventDefault();
    setSaving(true);

    try {
      await set(ref(db, "cai_dat/he_thong"), {
        ...managerConfig,
        ...systemSettings,
        updated_at: new Date().toISOString(),
      });
      await set(ref(db, "cai_dat/bank"), {
        ...bankConfig,
        bank_id: bankConfig.ma_bin || bankConfig.ten_ngan_hang,
        account_no: bankConfig.so_tai_khoan,
        account_name: bankConfig.ten_chu_tai_khoan,
        updated_at: new Date().toISOString(),
      });

      showNotification("Đã lưu thành công cấu hình thông tin quản lý & VietQR!");
    } catch (err) {
      showNotification("Lỗi khi lưu cài đặt: " + err.message, true);
    } finally {
      setSaving(false);
    }
  };

  // --- POINT RULES CRUD ---
  const handleOpenRuleModal = (rule = null, index = null) => {
    if (rule !== null && index !== null) {
      setEditingRuleIndex(index);
      setRuleFormData({
        ten: rule.ten || "",
        diem: rule.diem ?? 10,
        mo_ta: rule.mo_ta || "",
      });
    } else {
      setEditingRuleIndex(null);
      setRuleFormData({
        ten: "",
        diem: 10,
        mo_ta: "",
      });
    }
    setShowRuleModal(true);
  };

  const handleSaveRule = async (e) => {
    e.preventDefault();
    if (!ruleFormData.ten.trim()) return;

    let updatedList = [...pointRules];
    if (editingRuleIndex !== null) {
      updatedList[editingRuleIndex] = {
        ...updatedList[editingRuleIndex],
        ten: ruleFormData.ten.trim(),
        diem: Number(ruleFormData.diem),
        mo_ta: ruleFormData.mo_ta.trim(),
      };
    } else {
      const newRule = {
        id: "rule_" + Date.now(),
        ten: ruleFormData.ten.trim(),
        diem: Number(ruleFormData.diem),
        mo_ta: ruleFormData.mo_ta.trim(),
      };
      updatedList.push(newRule);
    }

    try {
      await set(ref(db, "cai_dat/quy_tac_diem"), updatedList);
      setPointRules(updatedList);
      setShowRuleModal(false);
      showNotification("Đã lưu quy tắc tích điểm thưởng thành công!");
    } catch (err) {
      showNotification("Lỗi lưu quy tắc điểm: " + err.message, true);
    }
  };

  const handleDeleteRule = async (index) => {
    if (confirm("Bạn có chắc chắn muốn xóa mục quy tắc tích điểm này?")) {
      const updatedList = pointRules.filter((_, idx) => idx !== index);
      try {
        await set(ref(db, "cai_dat/quy_tac_diem"), updatedList);
        setPointRules(updatedList);
        showNotification("Đã xóa quy tắc tích điểm thành công!");
      } catch (err) {
        showNotification("Lỗi xóa quy tắc điểm: " + err.message, true);
      }
    }
  };

  // --- SCHOOLS CRUD ---
  const handleOpenSchoolModal = (school = null) => {
    if (school) {
      setEditingSchool(school);
      setSchoolFormData({ ten: school.ten || "" });
    } else {
      setEditingSchool(null);
      setSchoolFormData({ ten: "" });
    }
    setShowSchoolModal(true);
  };

  const handleSaveSchool = async (e) => {
    e.preventDefault();
    if (!schoolFormData.ten.trim()) return;

    try {
      if (editingSchool) {
        const schoolRef = ref(db, `truong/${editingSchool._key}`);
        await set(schoolRef, {
          ...editingSchool,
          ten: schoolFormData.ten.trim(),
          updated_at: new Date().toISOString(),
        });
      } else {
        const newId = Date.now();
        const schoolRef = ref(db, `truong/${newId}`);
        await set(schoolRef, {
          id: newId,
          ten: schoolFormData.ten.trim(),
          created_at: new Date().toISOString(),
        });
      }
      setShowSchoolModal(false);
      showNotification("Đã lưu trường học thành công!");
    } catch (err) {
      showNotification("Lỗi lưu trường học: " + err.message, true);
    }
  };

  const handleDeleteSchool = async (key) => {
    if (confirm("Bạn có chắc chắn muốn xóa trường học này khỏi danh sách?")) {
      try {
        await remove(ref(db, `truong/${key}`));
        showNotification("Đã xóa trường học thành công!");
      } catch (err) {
        showNotification("Lỗi xóa trường học: " + err.message, true);
      }
    }
  };

  // --- RECALCULATE STUDENT REMAINING SESSIONS ---
  const handleRecalculateSessions = async () => {
    if (!confirm("Hệ thống sẽ tính toán lại chính xác số buổi dư của tất cả học sinh dựa trên lịch sử điểm danh và học phí đã nộp. Bạn có chắc chắn muốn tiếp tục?")) {
      return;
    }

    setRecalculating(true);
    try {
      const [hsSnap, ddSnap, ttSnap] = await Promise.all([
        get(ref(db, "hoc_sinh")),
        get(ref(db, "diem_danh")),
        get(ref(db, "thanh_toan")),
      ]);

      const hsData = hsSnap.val() || {};
      const ddData = ddSnap.val() || {};
      const ttData = ttSnap.val() || {};

      let totalUpdated = 0;

      for (const [key, hs] of Object.entries(hsData)) {
        if (!hs) continue;
        const studentId = hs.id || key;

        // Count sessions attended
        let sessionsAttended = 0;
        Object.values(ddData).forEach((dd) => {
          if (!dd) return;
          if (dd.danh_sach && Array.isArray(dd.danh_sach)) {
            dd.danh_sach.forEach((item) => {
              if (String(item.id_hoc_sinh) === String(studentId) && (item.trang_thai === "CO_MAT" || item.trang_thai === "MUON")) {
                sessionsAttended += 1;
              }
            });
          }
        });

        // Count sessions paid
        let sessionsPaid = Number(hs.so_buoi_ban_dau || 0);
        Object.values(ttData).forEach((tt) => {
          if (!tt) return;
          if (String(tt.id_hoc_sinh) === String(studentId)) {
            sessionsPaid += Number(tt.so_buoi_dong || 0);
          }
        });

        const remainingSessions = Math.max(0, sessionsPaid - sessionsAttended);

        // Update student record in Firebase
        await set(ref(db, `hoc_sinh/${key}/so_buoi_con_lai`), remainingSessions);
        totalUpdated += 1;
      }

      showNotification(`Tính toán lại số buổi dư thành công cho ${totalUpdated} học sinh!`);
    } catch (err) {
      showNotification("Lỗi khi tính toán số buổi dư: " + err.message, true);
    } finally {
      setRecalculating(false);
    }
  };

  // --- GOOGLE SHEETS BACKUP & RESTORE ---
  const handleBackupToGoogleSheets = async () => {
    if (!systemSettings.google_sheets_url.trim()) {
      showNotification("Vui lòng nhập Web App URL Google Sheets trước!", true);
      return;
    }

    setSyncingSheets(true);
    try {
      const dbSnap = await get(ref(db));
      const fullData = dbSnap.val() || {};

      const response = await fetch(systemSettings.google_sheets_url.trim(), {
        method: "POST",
        headers: { "Content-Type": "text/plain;charset=utf-8" },
        body: JSON.stringify({ action: "backup", data: fullData }),
      });

      const result = await response.json();
      if (result.status === "success") {
        showNotification("Sao lưu dữ liệu lên Google Sheets thành công!");
      } else {
        throw new Error(result.message || "Lỗi không xác định");
      }
    } catch (err) {
      showNotification("Lỗi sao lưu Google Sheets: " + err.message, true);
    } finally {
      setSyncingSheets(false);
    }
  };

  const handleRestoreFromGoogleSheets = async () => {
    if (!systemSettings.google_sheets_url.trim()) {
      showNotification("Vui lòng nhập Web App URL Google Sheets trước!", true);
      return;
    }

    if (!confirm("CẢNH BÁO: Dữ liệu hiện tại trên Cloud sẽ bị ghi đè hoàn toàn bằng dữ liệu từ Google Sheets. Bạn có chắc muốn tiếp tục?")) {
      return;
    }

    setSyncingSheets(true);
    try {
      const response = await fetch(`${systemSettings.google_sheets_url.trim()}?action=restore`);
      const result = await response.json();

      if (result.status === "success" && result.data) {
        for (const [table, content] of Object.entries(result.data)) {
          await set(ref(db, table), content);
        }
        showNotification("Khôi phục toàn bộ dữ liệu từ Google Sheets thành công!");
      } else {
        throw new Error(result.message || "Lỗi tải dữ liệu");
      }
    } catch (err) {
      showNotification("Lỗi khôi phục từ Google Sheets: " + err.message, true);
    } finally {
      setSyncingSheets(false);
    }
  };

  // --- EXPORT & IMPORT LOCAL JSON BACKUP ---
  const handleExportJSON = async () => {
    try {
      const dbSnap = await get(ref(db));
      const fullData = dbSnap.val() || {};

      const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(fullData, null, 2));
      const downloadAnchor = document.createElement("a");
      downloadAnchor.setAttribute("href", dataStr);
      downloadAnchor.setAttribute("download", `tuition_backup_${new Date().toISOString().slice(0, 10)}.json`);
      document.body.appendChild(downloadAnchor);
      downloadAnchor.click();
      downloadAnchor.remove();

      showNotification("Tải file sao lưu JSON thành công!");
    } catch (err) {
      showNotification("Lỗi xuất dữ liệu: " + err.message, true);
    }
  };

  return (
    <div>
      {/* Page Header */}
      <div style={{ marginBottom: "1.75rem" }}>
        <h2 style={{ fontSize: "1.75rem", fontWeight: "700" }}>Cài Đặt Hệ Thống</h2>
        <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem" }}>
          Cấu hình toàn diện thông tin quản lý, VietQR, quy tắc điểm thưởng, trường học & sao lưu dữ liệu
        </p>
      </div>

      {/* Alert Messages */}
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

      {errorMsg && (
        <div
          style={{
            padding: "1rem 1.25rem",
            backgroundColor: "rgba(239, 68, 68, 0.15)",
            border: "1px solid var(--danger)",
            borderRadius: "var(--radius-md)",
            color: "var(--danger)",
            marginBottom: "1.5rem",
            display: "flex",
            alignItems: "center",
            gap: "0.5rem",
          }}
        >
          <X size={20} />
          <span style={{ fontWeight: "600" }}>{errorMsg}</span>
        </div>
      )}

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(360px, 1fr))", gap: "1.5rem" }}>
        {/* Column 1: Manager & Bank VietQR Config */}
        <div style={{ display: "flex", flexDirection: "column", gap: "1.5rem" }}>
          {/* Manager & Tuition Settings Card */}
          <div className="glass-panel" style={{ padding: "1.5rem" }}>
            <h3
              style={{
                fontSize: "1.1rem",
                fontWeight: "700",
                marginBottom: "1.25rem",
                display: "flex",
                alignItems: "center",
                gap: "0.5rem",
              }}
            >
              <UserCheck size={20} color="var(--accent-primary)" />
              Thông Tin Quản Lý & Mức Thu Học Phí
            </h3>

            <form onSubmit={handleSaveGeneral} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Tên người quản lý / Trung tâm
                </label>
                <input
                  type="text"
                  required
                  value={managerConfig.ten_quan_ly}
                  onChange={(e) => setManagerConfig({ ...managerConfig, ten_quan_ly: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Email liên hệ
                </label>
                <input
                  type="email"
                  required
                  value={managerConfig.email}
                  onChange={(e) => setManagerConfig({ ...managerConfig, email: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0.75rem" }}>
                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                    Học phí 1 buổi (VNĐ)
                  </label>
                  <input
                    type="number"
                    value={managerConfig.hoc_phi_buoi}
                    onChange={(e) => setManagerConfig({ ...managerConfig, hoc_phi_buoi: e.target.value })}
                    className="input-control"
                    style={{ width: "100%" }}
                  />
                </div>

                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                    Số buổi chuẩn/tháng
                  </label>
                  <input
                    type="number"
                    value={managerConfig.so_buoi_chuan_thang}
                    onChange={(e) => setManagerConfig({ ...managerConfig, so_buoi_chuan_thang: e.target.value })}
                    className="input-control"
                    style={{ width: "100%" }}
                  />
                </div>
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Mức thu học phí chuẩn theo tháng (VNĐ)
                </label>
                <input
                  type="number"
                  value={managerConfig.hoc_phi_thang}
                  onChange={(e) => setManagerConfig({ ...managerConfig, hoc_phi_thang: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              {/* VietQR Bank Settings Sub-section */}
              <div
                style={{
                  marginTop: "0.5rem",
                  paddingTop: "1rem",
                  borderTop: "1px solid rgba(255, 255, 255, 0.08)",
                }}
              >
                <h4 style={{ fontSize: "0.95rem", fontWeight: "700", marginBottom: "0.85rem", display: "flex", alignItems: "center", gap: "0.4rem" }}>
                  <CreditCard size={18} color="#3b82f6" /> Tài Khoản VietQR Thanh Toán
                </h4>

                <div style={{ display: "flex", flexDirection: "column", gap: "0.85rem" }}>
                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0.75rem" }}>
                    <div>
                      <label style={{ display: "block", fontSize: "0.8rem", fontWeight: "600", marginBottom: "0.3rem" }}>
                        Tên Ngân Hàng
                      </label>
                      <input
                        type="text"
                        placeholder="Sacombank, VCB..."
                        value={bankConfig.ten_ngan_hang || ""}
                        onChange={(e) => setBankConfig({ ...bankConfig, ten_ngan_hang: e.target.value })}
                        className="input-control"
                        style={{ width: "100%" }}
                      />
                    </div>
                    <div>
                      <label style={{ display: "block", fontSize: "0.8rem", fontWeight: "600", marginBottom: "0.3rem" }}>
                        Mã BIN (Tùy chọn)
                      </label>
                      <input
                        type="text"
                        placeholder="970403"
                        value={bankConfig.ma_bin || ""}
                        onChange={(e) => setBankConfig({ ...bankConfig, ma_bin: e.target.value })}
                        className="input-control"
                        style={{ width: "100%" }}
                      />
                    </div>
                  </div>

                  <div>
                    <label style={{ display: "block", fontSize: "0.8rem", fontWeight: "600", marginBottom: "0.3rem" }}>
                      Số Tài Khoản Ngân Hàng *
                    </label>
                    <input
                      type="text"
                      required
                      value={bankConfig.so_tai_khoan || ""}
                      onChange={(e) => setBankConfig({ ...bankConfig, so_tai_khoan: e.target.value })}
                      className="input-control"
                      style={{ width: "100%" }}
                    />
                  </div>

                  <div>
                    <label style={{ display: "block", fontSize: "0.8rem", fontWeight: "600", marginBottom: "0.3rem" }}>
                      Tên Chủ Tài Khoản (KHÔNG DẤU) *
                    </label>
                    <input
                      type="text"
                      required
                      value={bankConfig.ten_chu_tai_khoan || ""}
                      onChange={(e) => setBankConfig({ ...bankConfig, ten_chu_tai_khoan: e.target.value })}
                      className="input-control"
                      style={{ width: "100%" }}
                    />
                  </div>
                </div>
              </div>

              <button type="submit" disabled={saving} className="btn-primary" style={{ width: "100%", marginTop: "0.5rem" }}>
                <Save size={18} /> {saving ? "Đang Lưu..." : "Lưu Thông Tin Quản Lý & VietQR"}
              </button>
            </form>
          </div>

          {/* School List Management Card */}
          <div className="glass-panel" style={{ padding: "1.5rem" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem" }}>
              <h3 style={{ fontSize: "1.1rem", fontWeight: "700", display: "flex", alignItems: "center", gap: "0.5rem" }}>
                <School size={20} color="#06b6d4" />
                Danh Sách Trường Học ({schools.length})
              </h3>
              <button
                type="button"
                onClick={() => handleOpenSchoolModal()}
                className="btn-secondary"
                style={{ fontSize: "0.82rem", padding: "0.35rem 0.65rem", display: "inline-flex", alignItems: "center", gap: "0.3rem" }}
              >
                <Plus size={16} /> Thêm Trường
              </button>
            </div>

            {schools.length === 0 ? (
              <div style={{ fontSize: "0.85rem", color: "var(--text-muted)", padding: "1rem", textAlign: "center" }}>
                Chưa có trường học nào. Nhấp "+ Thêm Trường" để khởi tạo.
              </div>
            ) : (
              <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem", maxHeight: "240px", overflowY: "auto" }}>
                {schools.map((school) => (
                  <div
                    key={school._key}
                    style={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                      padding: "0.6rem 0.85rem",
                      borderRadius: "8px",
                      backgroundColor: "rgba(255, 255, 255, 0.04)",
                      border: "1px solid rgba(255, 255, 255, 0.06)",
                    }}
                  >
                    <span style={{ fontWeight: "600", fontSize: "0.9rem" }}>{school.ten}</span>
                    <div style={{ display: "flex", gap: "0.35rem" }}>
                      <button
                        onClick={() => handleOpenSchoolModal(school)}
                        className="btn-secondary"
                        style={{ padding: "0.25rem 0.45rem" }}
                        title="Sửa tên trường"
                      >
                        <Edit size={14} />
                      </button>
                      <button
                        onClick={() => handleDeleteSchool(school._key)}
                        className="btn-secondary"
                        style={{ padding: "0.25rem 0.45rem", color: "var(--danger)", borderColor: "rgba(239,68,68,0.3)" }}
                        title="Xóa trường"
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Column 2: Point Rules CRUD & Data Management */}
        <div style={{ display: "flex", flexDirection: "column", gap: "1.5rem" }}>
          {/* Bonus Point Rules Full CRUD Card */}
          <div className="glass-panel" style={{ padding: "1.5rem" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.25rem" }}>
              <div>
                <h3 style={{ fontSize: "1.1rem", fontWeight: "700", display: "flex", alignItems: "center", gap: "0.5rem" }}>
                  <Award size={20} color="var(--warning)" />
                  Xây Dựng Quy Tắc Tích Điểm Thưởng
                </h3>
                <p style={{ fontSize: "0.8rem", color: "var(--text-muted)", marginTop: "0.2rem" }}>
                  Thêm, sửa, xóa các mục quy tắc cộng/trừ điểm thưởng cho học sinh
                </p>
              </div>
              <button
                type="button"
                onClick={() => handleOpenRuleModal()}
                className="btn-primary"
                style={{
                  backgroundColor: "var(--warning)",
                  color: "#000000",
                  fontWeight: "700",
                  fontSize: "0.82rem",
                  padding: "0.4rem 0.75rem",
                }}
              >
                <Plus size={16} /> Thêm Quy Tắc
              </button>
            </div>

            {/* Point Rules List */}
            <div style={{ display: "flex", flexDirection: "column", gap: "0.75rem" }}>
              {pointRules.map((rule, idx) => (
                <div
                  key={rule.id || idx}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "space-between",
                    padding: "0.75rem 1rem",
                    borderRadius: "10px",
                    backgroundColor: "rgba(255, 255, 255, 0.04)",
                    border: "1px solid rgba(255, 255, 255, 0.08)",
                  }}
                >
                  <div style={{ flex: 1, paddingRight: "0.75rem" }}>
                    <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                      <span style={{ fontWeight: "700", fontSize: "0.95rem" }}>{rule.ten}</span>
                      <span
                        style={{
                          fontSize: "0.78rem",
                          fontWeight: "700",
                          backgroundColor: rule.diem >= 0 ? "rgba(34, 197, 94, 0.15)" : "rgba(239, 68, 68, 0.15)",
                          color: rule.diem >= 0 ? "#22c55e" : "#ef4444",
                          padding: "0.15rem 0.5rem",
                          borderRadius: "12px",
                          border: rule.diem >= 0 ? "1px solid rgba(34, 197, 94, 0.3)" : "1px solid rgba(239, 68, 68, 0.3)",
                        }}
                      >
                        {rule.diem >= 0 ? `+${rule.diem} pts` : `${rule.diem} pts`}
                      </span>
                    </div>
                    {rule.mo_ta && <div style={{ fontSize: "0.8rem", color: "var(--text-muted)", marginTop: "0.2rem" }}>{rule.mo_ta}</div>}
                  </div>

                  <div style={{ display: "flex", gap: "0.4rem" }}>
                    <button
                      type="button"
                      onClick={() => handleOpenRuleModal(rule, idx)}
                      className="btn-secondary"
                      style={{ padding: "0.35rem 0.55rem" }}
                      title="Chỉnh sửa quy tắc"
                    >
                      <Edit size={14} />
                    </button>
                    <button
                      type="button"
                      onClick={() => handleDeleteRule(idx)}
                      className="btn-secondary"
                      style={{ padding: "0.35rem 0.55rem", color: "var(--danger)", borderColor: "rgba(239,68,68,0.3)" }}
                      title="Xóa quy tắc"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Data Management & Recalculate Sessions */}
          <div className="glass-panel" style={{ padding: "1.5rem" }}>
            <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1.25rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
              <Calculator size={20} color="#a855f7" />
              Quản Lý Dữ Liệu & Tính Toán
            </h3>

            <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              {/* Recalculate Student Remaining Sessions Button */}
              <button
                type="button"
                onClick={handleRecalculateSessions}
                disabled={recalculating}
                className="btn-primary"
                style={{
                  backgroundColor: "#8b5cf6",
                  color: "#ffffff",
                  fontWeight: "700",
                  width: "100%",
                  padding: "0.75rem",
                }}
              >
                <Calculator size={18} />
                {recalculating ? "Đang Tính Toán Lại Dữ Liệu..." : "Tính Toán Lại Số Buổi Dư Cho Tất Cả Học Sinh"}
              </button>

              {/* Local Backup JSON */}
              <div style={{ display: "flex", gap: "0.75rem", marginTop: "0.5rem" }}>
                <button
                  type="button"
                  onClick={handleExportJSON}
                  className="btn-secondary"
                  style={{ flex: 1, justifyContent: "center" }}
                >
                  <CloudUpload size={16} /> Xuất File JSON Backup
                </button>
              </div>
            </div>
          </div>

          {/* Google Sheets Backup / Restore Cloud Sync */}
          <div className="glass-panel" style={{ padding: "1.5rem" }}>
            <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
              <FileSpreadsheet size={20} color="#10b981" />
              Sao Lưu & Khôi Phục Google Sheets
            </h3>

            <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Đường dẫn Google Apps Script Web App URL:
                </label>
                <input
                  type="url"
                  placeholder="https://script.google.com/macros/s/.../exec"
                  value={systemSettings.google_sheets_url}
                  onChange={(e) => setSystemSettings({ ...systemSettings, google_sheets_url: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div style={{ display: "flex", gap: "0.75rem" }}>
                <button
                  type="button"
                  onClick={handleBackupToGoogleSheets}
                  disabled={syncingSheets}
                  className="btn-primary"
                  style={{ flex: 1, backgroundColor: "#0d9488", color: "#ffffff", justifyContent: "center" }}
                >
                  <CloudUpload size={16} /> {syncingSheets ? "Đang đẩy..." : "Lên Sheets"}
                </button>
                <button
                  type="button"
                  onClick={handleRestoreFromGoogleSheets}
                  disabled={syncingSheets}
                  className="btn-primary"
                  style={{ flex: 1, backgroundColor: "#6366f1", color: "#ffffff", justifyContent: "center" }}
                >
                  <CloudDownload size={16} /> {syncingSheets ? "Đang tải..." : "Tải từ Sheets"}
                </button>
              </div>

              <button
                type="button"
                onClick={() => setShowScriptGuideModal(true)}
                className="btn-secondary"
                style={{ width: "100%", justifyContent: "center", fontSize: "0.85rem" }}
              >
                <BookOpen size={16} /> Xem Hướng Dẫn Cài Đặt Apps Script
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Modal Add / Edit Bonus Point Rule */}
      {showRuleModal && (
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
              {editingRuleIndex !== null ? "Chỉnh Sửa Quy Tắc Điểm Thưởng" : "Thêm Quy Tắc Tích Điểm Mới"}
            </h3>

            <form onSubmit={handleSaveRule} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Tên quy tắc *
                </label>
                <input
                  type="text"
                  required
                  placeholder="Ví dụ: Giúp đỡ bạn học, Phát biểu tích cực..."
                  value={ruleFormData.ten}
                  onChange={(e) => setRuleFormData({ ...ruleFormData, ten: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Số điểm thưởng (+ hoặc -) *
                </label>
                <input
                  type="number"
                  required
                  placeholder="Ví dụ: 10 hoặc -5"
                  value={ruleFormData.diem}
                  onChange={(e) => setRuleFormData({ ...ruleFormData, diem: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Mô tả quy tắc
                </label>
                <textarea
                  rows={3}
                  placeholder="Mô tả trường hợp áp dụng cộng/trừ điểm..."
                  value={ruleFormData.mo_ta}
                  onChange={(e) => setRuleFormData({ ...ruleFormData, mo_ta: e.target.value })}
                  className="input-control"
                  style={{ width: "100%", resize: "vertical" }}
                />
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "1rem" }}>
                <button type="button" onClick={() => setShowRuleModal(false)} className="btn-secondary">
                  Hủy
                </button>
                <button type="submit" className="btn-primary" style={{ backgroundColor: "var(--warning)", color: "#000" }}>
                  {editingRuleIndex !== null ? "Cập Nhật" : "Tạo Mới"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Add / Edit School */}
      {showSchoolModal && (
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
          <div className="glass-panel" style={{ width: "100%", maxWidth: "420px", padding: "1.75rem", backgroundColor: "var(--bg-secondary)" }}>
            <h3 style={{ fontSize: "1.25rem", fontWeight: "700", marginBottom: "1.25rem" }}>
              {editingSchool ? "Chỉnh Sửa Tên Trường Học" : "Thêm Trường Học Mới"}
            </h3>

            <form onSubmit={handleSaveSchool} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Tên trường học *
                </label>
                <input
                  type="text"
                  required
                  placeholder="Ví dụ: THPT Chuyên Lê Hồng Phong"
                  value={schoolFormData.ten}
                  onChange={(e) => setSchoolFormData({ ...schoolFormData, ten: e.target.value })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "1rem" }}>
                <button type="button" onClick={() => setShowSchoolModal(false)} className="btn-secondary">
                  Hủy
                </button>
                <button type="submit" className="btn-primary">
                  {editingSchool ? "Cập Nhật" : "Tạo Mới"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Apps Script Instructions */}
      {showScriptGuideModal && (
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
            style={{
              width: "100%",
              maxWidth: "680px",
              maxHeight: "85vh",
              overflowY: "auto",
              padding: "1.75rem",
              backgroundColor: "var(--bg-secondary)",
            }}
          >
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem" }}>
              <h3 style={{ fontSize: "1.25rem", fontWeight: "700", display: "flex", alignItems: "center", gap: "0.5rem" }}>
                <Code size={20} color="var(--accent-primary)" />
                Hướng Dẫn Cài Đặt Google Apps Script
              </h3>
              <button onClick={() => setShowScriptGuideModal(false)} className="btn-secondary" style={{ padding: "0.25rem 0.5rem" }}>
                <X size={18} />
              </button>
            </div>

            <div style={{ fontSize: "0.88rem", color: "var(--text-secondary)", lineHeight: "1.6" }}>
              <ol style={{ paddingLeft: "1.25rem", marginBottom: "1rem" }}>
                <li>Tạo một file Google Sheets mới trên Google Drive của bạn.</li>
                <li>Vào Tiện ích mở rộng (&gt;) Apps Script.</li>
                <li>Xóa hết code mặc định và dán đoạn mã bên dưới vào.</li>
                <li>Nhấn nút Lưu và chọn <strong>Triển khai &gt; Triển khai mới</strong>.</li>
                <li>Chọn loại là <strong>Ứng dụng web (Web App)</strong>.</li>
                <li>Tại phần "Ai có quyền truy cập", chọn <strong>Bất kỳ ai (Anyone)</strong>.</li>
                <li>Nhấn Triển khai, cấp quyền và dán Web App URL vào ô cài đặt trên Web hoặc App Android.</li>
              </ol>

              <div
                style={{
                  backgroundColor: "rgba(0, 0, 0, 0.4)",
                  padding: "1rem",
                  borderRadius: "8px",
                  fontSize: "0.78rem",
                  fontFamily: "monospace",
                  border: "1px solid rgba(255, 255, 255, 0.1)",
                  overflowX: "auto",
                  whiteSpace: "pre-wrap",
                }}
              >
{`function doPost(e) {
  try {
    var payload = JSON.parse(e.postData.contents);
    if (payload.action === "backup") {
      var data = payload.data;
      var ss = SpreadsheetApp.getActiveSpreadsheet();
      for (var tableName in data) {
        var sheet = ss.getSheetByName(tableName) || ss.insertSheet(tableName);
        sheet.clear();
        var rows = data[tableName];
        if (rows && rows.length > 0) {
          var headers = Object.keys(rows[0]);
          sheet.appendRow(headers);
          var values = rows.map(function(row) {
            return headers.map(function(h) { return (row[h] === null || row[h] === undefined) ? "" : row[h]; });
          });
          sheet.getRange(2, 1, values.length, headers.length).setValues(values);
        }
      }
      return ContentService.createTextOutput(JSON.stringify({status: "success"})).setMimeType(ContentService.MimeType.JSON);
    }
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({status: "error", message: err.toString()})).setMimeType(ContentService.MimeType.JSON);
  }
}

function doGet(e) {
  try {
    if (e.parameter.action === "restore") {
      var ss = SpreadsheetApp.getActiveSpreadsheet();
      var sheets = ss.getSheets();
      var data = {};
      for (var i = 0; i < sheets.length; i++) {
        var sheet = sheets[i];
        var tableName = sheet.getName();
        var values = sheet.getDataRange().getValues();
        if (values.length > 1) {
          var headers = values[0];
          var rows = [];
          for (var r = 1; r < values.length; r++) {
            var row = {};
            for (var c = 0; c < headers.length; c++) {
              row[headers[c]] = values[r][c];
            }
            rows.push(row);
          }
          data[tableName] = rows;
        }
      }
      return ContentService.createTextOutput(JSON.stringify({status: "success", data: data})).setMimeType(ContentService.MimeType.JSON);
    }
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({status: "error", message: err.toString()})).setMimeType(ContentService.MimeType.JSON);
  }
}`}
              </div>
            </div>

            <div style={{ display: "flex", justifyContent: "flex-end", marginTop: "1.25rem" }}>
              <button type="button" onClick={() => setShowScriptGuideModal(false)} className="btn-primary">
                Đã Hiểu
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
