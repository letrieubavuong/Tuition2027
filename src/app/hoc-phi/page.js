"use client";

import { useEffect, useState } from "react";
import { db, ref, onValue, set } from "@/lib/firebase";
import { CreditCard, CheckCircle2, AlertTriangle, QrCode, Search, DollarSign, Calendar, Filter, Phone } from "lucide-react";

export default function HocPhiPage() {
  const [payments, setPayments] = useState([]);
  const [studentsMap, setStudentsMap] = useState({});
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("all"); // all, paid, debt
  const [selectedMonth, setSelectedMonth] = useState("all");
  const [availableMonths, setAvailableMonths] = useState([]);
  const [selectedQr, setSelectedQr] = useState(null);

  useEffect(() => {
    // 1. Lắng nghe danh sách học sinh để map ID -> Tên học sinh
    const hsRef = ref(db, "hoc_sinh");
    const unsubHs = onValue(hsRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        const sMap = {};
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        list.forEach((s) => {
          if (s && s.id !== undefined) {
            sMap[s.id] = s;
          }
        });
        setStudentsMap(sMap);
      }
    });

    // 2. Lắng nghe danh sách đóng tiền
    const thanhToanRef = ref(db, "thanh_toan");
    const unsubPay = onValue(thanhToanRef, (snapshot) => {
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

        // Thu thập danh sách các tháng có dữ liệu
        const months = Array.from(
          new Set(list.map((p) => p.thang).filter(Boolean))
        ).sort((a, b) => b.localeCompare(a));
        setAvailableMonths(months);

        // Mặc định chọn tháng mới nhất nếu có
        if (months.length > 0 && selectedMonth === "all") {
          setSelectedMonth(months[0]);
        }
      } else {
        setPayments([]);
      }
      setLoading(false);
    });

    return () => {
      unsubHs();
      unsubPay();
    };
  }, []);

  const formatCurrency = (num) => {
    return new Intl.NumberFormat("vi-VN", {
      style: "currency",
      currency: "VND",
    }).format(num || 0);
  };

  const getStudentName = (p) => {
    if (p.ten_hoc_sinh && p.ten_hoc_sinh.trim() !== "") {
      return p.ten_hoc_sinh;
    }
    const s = studentsMap[p.id_hoc_sinh];
    if (s && s.ten) {
      return s.ten;
    }
    return `Học sinh #${p.id_hoc_sinh}`;
  };

  const getStudentPhone = (p) => {
    const s = studentsMap[p.id_hoc_sinh];
    return s ? (s.sdt_phu_huynh || s.sdt || "") : "";
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
    const sName = getStudentName(p);
    const matchesSearch =
      (sName && sName.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (p.thang && p.thang.includes(searchQuery));

    const matchesMonth = selectedMonth === "all" || p.thang === selectedMonth;

    const daDong = Number(p.so_tien_da_dong) || 0;
    const tong = Number(p.tong_thanh_toan) || 0;
    const isPaid = daDong >= tong && tong > 0;

    if (!matchesMonth || !matchesSearch) return false;

    if (statusFilter === "paid") return isPaid;
    if (statusFilter === "debt") return !isPaid;
    return true;
  });

  // Calculate monthly stats
  const totalMonthAmount = filteredPayments.reduce((sum, p) => sum + (Number(p.tong_thanh_toan) || 0), 0);
  const totalMonthPaid = filteredPayments.reduce((sum, p) => sum + (Number(p.so_tien_da_dong) || 0), 0);
  const totalMonthDebt = Math.max(0, totalMonthAmount - totalMonthPaid);

  return (
    <div>
      {/* Page Header */}
      <div style={{ marginBottom: "1.75rem" }}>
        <h2 style={{ fontSize: "1.75rem", fontWeight: "700" }}>Quản Lý Học Phí & Thu Ngân</h2>
        <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem" }}>
          Theo dõi công nợ, chọn tháng cần xem và tạo mã VietQR nhắc đóng học phí
        </p>
      </div>

      {/* Control Bar & Month Selector */}
      <div className="glass-panel" style={{ padding: "1.25rem", marginBottom: "1.5rem" }}>
        <div style={{ display: "flex", gap: "1rem", flexWrap: "wrap", alignItems: "center", justifyContent: "space-between" }}>
          {/* Search Box */}
          <div style={{ position: "relative", flex: 1, minWidth: "260px" }}>
            <Search
              size={18}
              color="var(--text-muted)"
              style={{ position: "absolute", left: "1rem", top: "50%", transform: "translateY(-50%)" }}
            />
            <input
              type="text"
              placeholder="Tìm tên học sinh..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="input-control"
              style={{ width: "100%", paddingLeft: "2.75rem" }}
            />
          </div>

          {/* Month Dropdown Selector */}
          <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <Calendar size={18} color="var(--accent-primary)" />
            <span style={{ fontSize: "0.9rem", fontWeight: "600" }}>Chọn Tháng:</span>
            <select
              value={selectedMonth}
              onChange={(e) => setSelectedMonth(e.target.value)}
              className="input-control"
              style={{ padding: "0.6rem 1rem", fontSize: "0.9rem", fontWeight: "600", cursor: "pointer" }}
            >
              <option value="all">📅 Tất cả các tháng</option>
              {availableMonths.map((m) => (
                <option key={m} value={m}>
                  🗓️ Tháng {m}
                </option>
              ))}
            </select>
          </div>

          {/* Status Filter Tabs */}
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

        {/* Monthly Summary Bar */}
        <div
          style={{
            marginTop: "1.25rem",
            paddingTop: "1rem",
            borderTop: "1px solid var(--border-color)",
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))",
            gap: "1rem",
          }}
        >
          <div>
            <span style={{ fontSize: "0.8rem", color: "var(--text-muted)", fontWeight: "600" }}>TỔNG CẦN THU:</span>
            <div style={{ fontSize: "1.2rem", fontWeight: "800" }}>{formatCurrency(totalMonthAmount)}</div>
          </div>
          <div>
            <span style={{ fontSize: "0.8rem", color: "var(--text-muted)", fontWeight: "600" }}>ĐÃ THU:</span>
            <div style={{ fontSize: "1.2rem", fontWeight: "800", color: "var(--success)" }}>{formatCurrency(totalMonthPaid)}</div>
          </div>
          <div>
            <span style={{ fontSize: "0.8rem", color: "var(--text-muted)", fontWeight: "600" }}>CÒN NỢ:</span>
            <div style={{ fontSize: "1.2rem", fontWeight: "800", color: "var(--danger)" }}>{formatCurrency(totalMonthDebt)}</div>
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
            Không tìm thấy bản ghi học phí nào cho {selectedMonth === "all" ? "tất cả các tháng" : `tháng ${selectedMonth}`}.
          </div>
        ) : (
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Họ & Tên Học Sinh</th>
                  <th>Tháng</th>
                  <th>Tổng Tiền</th>
                  <th>Đã Đóng</th>
                  <th>Còn Nợ</th>
                  <th>Trạng Thái</th>
                  <th style={{ textAlign: "right" }}>VietQR / Thao Tác</th>
                </tr>
              </thead>
              <tbody>
                {filteredPayments.map((p) => {
                  const studentName = getStudentName(p);
                  const studentPhone = getStudentPhone(p);
                  const daDong = Number(p.so_tien_da_dong) || 0;
                  const tong = Number(p.tong_thanh_toan) || 0;
                  const conNo = Math.max(0, tong - daDong);
                  const isPaid = daDong >= tong && tong > 0;

                  return (
                    <tr key={p._key}>
                      <td>
                        <div style={{ fontWeight: "700", color: "var(--text-primary)", fontSize: "0.95rem" }}>
                          {studentName}
                        </div>
                        {studentPhone && (
                          <div style={{ fontSize: "0.78rem", color: "var(--accent-primary)", marginTop: "0.15rem", display: "flex", alignItems: "center", gap: "0.25rem" }}>
                            <Phone size={12} /> {studentPhone}
                          </div>
                        )}
                      </td>
                      <td>
                        <span className="badge badge-info">Tháng {p.thang || "--"}</span>
                      </td>
                      <td style={{ fontWeight: "600" }}>{formatCurrency(tong)}</td>
                      <td style={{ color: "var(--success)", fontWeight: "600" }}>{formatCurrency(daDong)}</td>
                      <td style={{ color: conNo > 0 ? "var(--danger)" : "var(--text-muted)", fontWeight: "700" }}>
                        {formatCurrency(conNo)}
                      </td>
                      <td>
                        {isPaid ? (
                          <span className="badge badge-success">
                            <CheckCircle2 size={12} /> Đã xong
                          </span>
                        ) : (
                          <span className="badge badge-warning">
                            <AlertTriangle size={12} /> Còn nợ {formatCurrency(conNo)}
                          </span>
                        )}
                      </td>
                      <td style={{ textAlign: "right" }}>
                        <div style={{ display: "flex", gap: "0.4rem", justifyContent: "flex-end" }}>
                          {studentPhone && (
                            <button
                              onClick={() => {
                                const clean = studentPhone.replace(/[^0-9]/g, "");
                                window.open(`https://zalo.me/${clean}`, "_blank");
                              }}
                              style={{
                                backgroundColor: "#0068ff",
                                color: "#ffffff",
                                border: "none",
                                borderRadius: "var(--radius-md)",
                                padding: "0.4rem 0.65rem",
                                fontSize: "0.8rem",
                                fontWeight: "600",
                                cursor: "pointer",
                                display: "inline-flex",
                                alignItems: "center",
                                gap: "0.25rem",
                              }}
                              title="Nhắn tin Zalo phụ huynh"
                            >
                              Zalo
                            </button>
                          )}

                          {conNo > 0 && (
                            <button
                              onClick={() =>
                                setSelectedQr({
                                  ten: studentName,
                                  sotien: conNo,
                                  noidung: `HOCPHI THANG ${p.thang || ""} ${studentName}`,
                                })
                              }
                              className="btn-secondary"
                              style={{ padding: "0.4rem 0.65rem", color: "var(--accent-primary)" }}
                              title="Tạo mã VietQR chuyển khoản"
                            >
                              <QrCode size={14} /> VietQR
                            </button>
                          )}

                          <button
                            onClick={() => {
                              const val = prompt(`Cập nhật số tiền đã đóng cho ${studentName} (VND):`, daDong);
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
