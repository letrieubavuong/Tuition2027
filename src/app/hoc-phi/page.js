"use client";

import { useEffect, useState } from "react";
import { db, ref, onValue, set } from "@/lib/firebase";
import { CreditCard, CheckCircle2, AlertTriangle, QrCode, Search, DollarSign } from "lucide-react";

export default function HocPhiPage() {
  const [payments, setPayments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("all"); // all, paid, debt
  const [selectedQr, setSelectedQr] = useState(null);

  useEffect(() => {
    const thanhToanRef = ref(db, "thanh_toan");
    const unsub = onValue(thanhToanRef, (snapshot) => {
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
        setPayments(list);
      } else {
        setPayments([]);
      }
      setLoading(false);
    });

    return () => unsub();
  }, []);

  const formatCurrency = (num) => {
    return new Intl.NumberFormat("vi-VN", {
      style: "currency",
      currency: "VND",
    }).format(num || 0);
  };

  const handleUpdatePaidAmount = async (payment, newAmount) => {
    try {
      const pRef = ref(db, `thanh_toan/${payment._key}`);
      await set(pRef, {
        ...payment,
        so_tien_da_dong: Number(newAmount),
        updated_at: new Date().toISOString(),
      });
    } catch (err) {
      alert("Lỗi cập nhật số tiền đóng: " + err.message);
    }
  };

  const filteredPayments = payments.filter((p) => {
    const matchesSearch =
      (p.ten_hoc_sinh && p.ten_hoc_sinh.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (p.thang && p.thang.includes(searchQuery));

    const daDong = Number(p.so_tien_da_dong) || 0;
    const tong = Number(p.tong_thanh_toan) || 0;
    const isPaid = daDong >= tong && tong > 0;

    if (statusFilter === "paid") return matchesSearch && isPaid;
    if (statusFilter === "debt") return matchesSearch && !isPaid;
    return matchesSearch;
  });

  return (
    <div>
      {/* Page Header */}
      <div style={{ marginBottom: "1.75rem" }}>
        <h2 style={{ fontSize: "1.75rem", fontWeight: "700" }}>Quản Lý Học Phí & Thu Ngân</h2>
        <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem" }}>
          Theo dõi công nợ, học phí tháng và tạo mã VietQR nhắc đóng học phí
        </p>
      </div>

      {/* Control Bar */}
      <div className="glass-panel" style={{ padding: "1rem 1.25rem", marginBottom: "1.5rem" }}>
        <div style={{ display: "flex", gap: "1rem", flexWrap: "wrap", alignItems: "center" }}>
          <div style={{ position: "relative", flex: 1, minWidth: "260px" }}>
            <Search
              size={18}
              color="var(--text-muted)"
              style={{ position: "absolute", left: "1rem", top: "50%", transform: "translateY(-50%)" }}
            />
            <input
              type="text"
              placeholder="Tìm theo tên học sinh, tháng..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="input-control"
              style={{ width: "100%", paddingLeft: "2.75rem" }}
            />
          </div>

          <div style={{ display: "flex", gap: "0.5rem" }}>
            <button
              onClick={() => setStatusFilter("all")}
              className={statusFilter === "all" ? "btn-primary" : "btn-secondary"}
              style={{ padding: "0.6rem 1rem", fontSize: "0.85rem" }}
            >
              Tất Cả
            </button>
            <button
              onClick={() => setStatusFilter("debt")}
              className={statusFilter === "debt" ? "btn-primary" : "btn-secondary"}
              style={{ padding: "0.6rem 1rem", fontSize: "0.85rem" }}
            >
              Còn Nợ
            </button>
            <button
              onClick={() => setStatusFilter("paid")}
              className={statusFilter === "paid" ? "btn-primary" : "btn-secondary"}
              style={{ padding: "0.6rem 1rem", fontSize: "0.85rem" }}
            >
              Đã Xong
            </button>
          </div>
        </div>
      </div>

      {/* Payment Data Table */}
      <div className="glass-panel" style={{ overflow: "hidden" }}>
        {loading ? (
          <div style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
            Đang nạp dữ liệu học phí...
          </div>
        ) : filteredPayments.length === 0 ? (
          <div style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
            Không tìm thấy bản ghi học phí nào.
          </div>
        ) : (
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Tháng / Học Sinh</th>
                  <th>Tổng Tiền</th>
                  <th>Đã Đóng</th>
                  <th>Còn Nợ</th>
                  <th>Trạng Thái</th>
                  <th style={{ textAlign: "right" }}>VietQR / Thao Tác</th>
                </tr>
              </thead>
              <tbody>
                {filteredPayments.map((p) => {
                  const daDong = Number(p.so_tien_da_dong) || 0;
                  const tong = Number(p.tong_thanh_toan) || 0;
                  const conNo = Math.max(0, tong - daDong);
                  const isPaid = daDong >= tong && tong > 0;

                  return (
                    <tr key={p._key}>
                      <td>
                        <div style={{ fontWeight: "700" }}>{p.ten_hoc_sinh || `Học sinh #${p.id_hoc_sinh}`}</div>
                        <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>Tháng: {p.thang || "--"}</div>
                      </td>
                      <td style={{ fontWeight: "600" }}>{formatCurrency(tong)}</td>
                      <td style={{ color: "var(--success)", fontWeight: "600" }}>{formatCurrency(daDong)}</td>
                      <td style={{ color: conNo > 0 ? "var(--danger)" : "var(--text-muted)", fontWeight: "700" }}>
                        {formatCurrency(conNo)}
                      </td>
                      <td>
                        {isPaid ? (
                          <span className="badge badge-success">
                            <CheckCircle2 size={12} /> Đã hoàn thành
                          </span>
                        ) : (
                          <span className="badge badge-warning">
                            <AlertTriangle size={12} /> Còn nợ {formatCurrency(conNo)}
                          </span>
                        )}
                      </td>
                      <td style={{ textAlign: "right" }}>
                        <div style={{ display: "flex", gap: "0.5rem", justifyContent: "flex-end" }}>
                          {conNo > 0 && (
                            <button
                              onClick={() =>
                                setSelectedQr({
                                  ten: p.ten_hoc_sinh,
                                  sotien: conNo,
                                  noidung: `HOCPHI THANG ${p.thang || ""} ${p.ten_hoc_sinh || ""}`,
                                })
                              }
                              className="btn-secondary"
                              style={{ padding: "0.4rem 0.65rem", color: "var(--accent-primary)" }}
                              title="Tạo VietQR chuyển khoản"
                            >
                              <QrCode size={14} /> VietQR
                            </button>
                          )}

                          <button
                            onClick={() => {
                              const val = prompt("Nhập số tiền đã đóng mới (VND):", daDong);
                              if (val !== null && !isNaN(val)) {
                                handleUpdatePaidAmount(p, val);
                              }
                            }}
                            className="btn-secondary"
                            style={{ padding: "0.4rem 0.65rem" }}
                          >
                            <DollarSign size={14} /> Cập nhật
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* VietQR Modal */}
      {selectedQr && (
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
          <div className="glass-panel" style={{ width: "100%", maxWidth: "420px", padding: "1.75rem", backgroundColor: "var(--bg-secondary)", textAlign: "center" }}>
            <h3 style={{ fontSize: "1.2rem", fontWeight: "700", marginBottom: "0.5rem" }}>
              Mã VietQR Nhắc Đóng Học Phí
            </h3>
            <p style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginBottom: "1.25rem" }}>
              Phụ huynh quét mã bên dưới để chuyển khoản chính xác số tiền nợ
            </p>

            <div style={{ background: "#ffffff", padding: "1rem", borderRadius: "16px", display: "inline-block", marginBottom: "1rem" }}>
              <img
                src={`https://img.vietqr.io/image/970422-0123456789-compact2.png?amount=${selectedQr.sotien}&addInfo=${encodeURIComponent(selectedQr.noidung)}&accountName=TUITION2026`}
                alt="VietQR"
                style={{ width: "240px", height: "240px" }}
              />
            </div>

            <div style={{ textAlign: "left", backgroundColor: "var(--bg-primary)", padding: "0.85rem", borderRadius: "8px", fontSize: "0.85rem", marginBottom: "1.25rem" }}>
              <div><strong>Học sinh:</strong> {selectedQr.ten}</div>
              <div><strong>Số tiền nợ:</strong> <span style={{ color: "var(--danger)", fontWeight: "700" }}>{formatCurrency(selectedQr.sotien)}</span></div>
              <div><strong>Nội dung CK:</strong> {selectedQr.noidung}</div>
            </div>

            <button onClick={() => setSelectedQr(null)} className="btn-primary" style={{ width: "100%", justifyContent: "center" }}>
              Đóng
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
