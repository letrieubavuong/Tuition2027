"use client";

import { useEffect, useState } from "react";
import { db, ref, onValue, set } from "@/lib/firebase";
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
  HelpCircle
} from "lucide-react";

export default function CaiDatPage() {
  const [bankConfig, setBankConfig] = useState({
    ten_ngan_hang: "MBBank",
    ma_bin: "970422",
    so_tai_khoan: "",
    ten_chu_tai_khoan: "",
  });

  const [pointRules, setPointRules] = useState({
    co_mat: 10,
    vang_phep: 0,
    muon: 5,
    btvn_hoan_thanh: 10,
  });

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [successMsg, setSuccessMsg] = useState("");

  useEffect(() => {
    // Load Bank config from Firebase
    const bankRef = ref(db, "cai_dat/bank");
    const unsubBank = onValue(bankRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        setBankConfig(val);
      }
    });

    // Load Point rules from Firebase
    const rulesRef = ref(db, "cai_dat/quy_tac_diem");
    const unsubRules = onValue(rulesRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        setPointRules(val);
      }
      setLoading(false);
    });

    return () => {
      unsubBank();
      unsubRules();
    };
  }, []);

  const handleSaveBank = async (e) => {
    e.preventDefault();
    setSaving(true);
    setSuccessMsg("");

    try {
      await set(ref(db, "cai_dat/bank"), bankConfig);
      await set(ref(db, "cai_dat/quy_tac_diem"), pointRules);

      setSuccessMsg("Đã lưu cài đặt tài khoản ngân hàng VietQR & Quy tắc thành công!");
      setTimeout(() => setSuccessMsg(""), 4000);
    } catch (err) {
      alert("Lỗi khi lưu cài đặt: " + err.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div>
      {/* Header */}
      <div style={{ marginBottom: "1.75rem" }}>
        <h2 style={{ fontSize: "1.75rem", fontWeight: "700" }}>Cài Đặt Hệ Thống</h2>
        <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem" }}>
          Cấu hình tài khoản thanh toán VietQR, quy tắc cộng điểm và đồng bộ dữ liệu
        </p>
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

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(350px, 1fr))", gap: "1.5rem" }}>
        {/* VietQR Bank Settings Card */}
        <div className="glass-panel" style={{ padding: "1.5rem" }}>
          <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1.25rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <CreditCard size={20} color="var(--accent-primary)" />
            Cấu Hình Tài Khoản Ngân Hàng VietQR
          </h3>

          <form onSubmit={handleSaveBank} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
            <div>
              <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                Tên Ngân Hàng
              </label>
              <input
                type="text"
                required
                placeholder="Ví dụ: MBBank, Vietcombank, BIDV..."
                value={bankConfig.ten_ngan_hang || ""}
                onChange={(e) => setBankConfig({ ...bankConfig, ten_ngan_hang: e.target.value })}
                className="input-control"
                style={{ width: "100%" }}
              />
            </div>

            <div>
              <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                Mã BIN Ngân Hàng (Tùy chọn)
              </label>
              <input
                type="text"
                placeholder="Ví dụ: 970422 (MBBank)"
                value={bankConfig.ma_bin || ""}
                onChange={(e) => setBankConfig({ ...bankConfig, ma_bin: e.target.value })}
                className="input-control"
                style={{ width: "100%" }}
              />
            </div>

            <div>
              <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                Số Tài Khoản Ngân Hàng *
              </label>
              <input
                type="text"
                required
                placeholder="Nhập số tài khoản ngân hàng..."
                value={bankConfig.so_tai_khoan || ""}
                onChange={(e) => setBankConfig({ ...bankConfig, so_tai_khoan: e.target.value })}
                className="input-control"
                style={{ width: "100%" }}
              />
            </div>

            <div>
              <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                Tên Chủ Tài Khoản *
              </label>
              <input
                type="text"
                required
                placeholder="Ví dụ: NGUYEN VAN A"
                value={bankConfig.ten_chu_tai_khoan || ""}
                onChange={(e) => setBankConfig({ ...bankConfig, ten_chu_tai_khoan: e.target.value })}
                className="input-control"
                style={{ width: "100%" }}
              />
            </div>

            <div style={{ marginTop: "1rem" }}>
              <button type="submit" disabled={saving} className="btn-primary" style={{ width: "100%" }}>
                <Save size={18} /> {saving ? "Đang Lưu..." : "Lưu Cấu Hình VietQR"}
              </button>
            </div>
          </form>
        </div>

        {/* Point Rules & Guide */}
        <div style={{ display: "flex", flexDirection: "column", gap: "1.5rem" }}>
          {/* Bonus Point Rules */}
          <div className="glass-panel" style={{ padding: "1.5rem" }}>
            <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1.25rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
              <Award size={20} color="var(--warning)" />
              Xây Dựng Quy Tắc Tích Điểm Thưởng
            </h3>

            <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Điểm cộng Có Mặt đúng giờ (pts):
                </label>
                <input
                  type="number"
                  value={pointRules.co_mat ?? 10}
                  onChange={(e) => setPointRules({ ...pointRules, co_mat: Number(e.target.value) })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Điểm cộng Đi Muộn (pts):
                </label>
                <input
                  type="number"
                  value={pointRules.muon ?? 5}
                  onChange={(e) => setPointRules({ ...pointRules, muon: Number(e.target.value) })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Điểm hoàn thành BTVN / Bài Kiểm Tra (pts):
                </label>
                <input
                  type="number"
                  value={pointRules.btvn_hoan_thanh ?? 10}
                  onChange={(e) => setPointRules({ ...pointRules, btvn_hoan_thanh: Number(e.target.value) })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "600", marginBottom: "0.4rem" }}>
                  Điểm thưởng Bài kiểm tra điểm 10 / Xuất sắc (pts):
                </label>
                <input
                  type="number"
                  value={pointRules.kiem_tra_gioi ?? 20}
                  onChange={(e) => setPointRules({ ...pointRules, kiem_tra_gioi: Number(e.target.value) })}
                  className="input-control"
                  style={{ width: "100%" }}
                />
              </div>

              <button
                type="button"
                onClick={handleSaveBank}
                disabled={saving}
                className="btn-primary"
                style={{ backgroundColor: "var(--warning)", color: "#000000", fontWeight: "700", marginTop: "0.5rem" }}
              >
                <Save size={16} /> Lưu Quy Tắc Điểm Thưởng
              </button>
            </div>
          </div>

          {/* User Guide Card */}
          <div className="glass-panel" style={{ padding: "1.5rem" }}>
            <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "1rem", display: "flex", alignItems: "center", gap: "0.5rem" }}>
              <BookOpen size={20} color="#8b5cf6" />
              Hướng Dẫn Đăng Nhập & Đồng Bộ
            </h3>
            <p style={{ fontSize: "0.85rem", color: "var(--text-secondary)", lineHeight: "1.5" }}>
              Ứng dụng Web tự động kết nối và đồng bộ 2 chiều thời gian thực với Firebase Realtime Database. Tất cả thay đổi trên Web sẽ xuất hiện ngay trên app Android và ngược lại.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
