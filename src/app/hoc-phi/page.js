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
  const [bankConfig, setBankConfig] = useState({
    ten_ngan_hang: "Sacombank",
    ma_bin: "970403",
    so_tai_khoan: "0905073175",
    ten_chu_tai_khoan: "LE TRIEU BA VUONG",
  });

  useEffect(() => {
    // 1. Lắng nghe danh sách học sinh để map ID -> Tên học sinh
    const hsRef = ref(db, "hoc_sinh");
    const unsubHs = onValue(hsRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        const sMap = {};
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        list.forEach((s) => {
          if (s) {
            const keyStr = String(s.id ?? s._key ?? "");
            if (keyStr) sMap[keyStr] = s;
            if (s.id !== undefined) sMap[s.id] = s;
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
        let rawList = [];
        if (Array.isArray(val)) {
          rawList = val
            .map((item, idx) => (item ? { ...item, _key: item.id || idx } : null))
            .filter(Boolean);
        } else if (typeof val === "object") {
          rawList = Object.entries(val).map(([key, item]) => ({
            ...item,
            _key: key,
          }));
        }

        // Deduplicate payment records by unique key: id_hoc_sinh + id_lop + thang
        const payMap = new Map();
        rawList.forEach((p) => {
          const hsId = p.id_hoc_sinh ?? p.hoc_sinh_id;
          const lopId = p.id_lop ?? p.lop_id ?? "ALL";
          const monthKey = p.thang ?? p.month ?? "UNKNOWN";
          const uniqueKey = (hsId !== undefined && monthKey)
            ? `${hsId}_${lopId}_${monthKey}`
            : String(p.id || p._key);

          if (!payMap.has(uniqueKey)) {
            payMap.set(uniqueKey, p);
          } else {
            const existing = payMap.get(uniqueKey);
            const newTime = p.updated_at ? new Date(p.updated_at).getTime() : 0;
            const existingTime = existing.updated_at ? new Date(existing.updated_at).getTime() : 0;
            if (newTime >= existingTime) {
              payMap.set(uniqueKey, p);
            }
          }
        });

        const list = Array.from(payMap.values());
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

    // 3. Lắng nghe cấu hình tài khoản VietQR từ cài đặt
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

    return () => {
      unsubHs();
      unsubPay();
      unsubBank();
    };
  }, []);

  const formatCurrency = (num) => {
    return new Intl.NumberFormat("vi-VN", {
      style: "currency",
      currency: "VND",
    }).format(num || 0);
  };

  const formatMonthYear = (m) => {
    if (!m) return "";
    if (m.includes("-")) {
      const parts = m.split("-");
      if (parts.length === 2) {
        return `${parts[1]}/${parts[0]}`;
      }
    }
    return m;
  };

  const getStudentName = (p) => {
    if (p.ten_hoc_sinh && p.ten_hoc_sinh.trim() !== "") {
      return p.ten_hoc_sinh;
    }
    const hsId = p.id_hoc_sinh ?? p.hoc_sinh_id;
    const s = studentsMap[hsId] || studentsMap[String(hsId)];
    if (s && (s.ten || s.ho_ten)) {
      return s.ten || s.ho_ten;
    }
    return `Học sinh #${hsId}`;
  };

  const getStudentPhone = (p) => {
    const hsId = p.id_hoc_sinh ?? p.hoc_sinh_id;
    const s = studentsMap[hsId] || studentsMap[String(hsId)];
    return s ? (s.sdt_phu_huynh || s.sdt || s.so_dien_thoai || "") : "";
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
                  🗓️ Tháng {formatMonthYear(m)}
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
                        <span className="badge badge-info">Tháng {formatMonthYear(p.thang) || "--"}</span>
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
                                borderRadius: "var(--radius-md)",
                                padding: "0.4rem 0.65rem",
                                fontSize: "0.8rem",
                                fontWeight: "600",
                                cursor: "pointer",
                                display: "inline-flex",
                                alignItems: "center",
                                gap: "0.25rem",
                              }}
                              title="Mở ứng dụng Zalo PC nhắn tin phụ huynh"
                            >
                              Zalo PC
                            </button>
                          )}

                          {conNo > 0 && (
                            <button
                              onClick={() =>
                                setSelectedQr({
                                  ten: studentName,
                                  sotien: conNo,
                                  noidung: `HOCPHI THANG ${formatMonthYear(p.thang)} ${studentName}`,
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
      {selectedQr && (() => {
        const bin = bankConfig.ma_bin || "970403";
        const stk = bankConfig.so_tai_khoan || "0905073175";
        const ctk = bankConfig.ten_chu_tai_khoan || "LE TRIEU BA VUONG";
        const bankName = bankConfig.ten_ngan_hang || "Sacombank";

        return (
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
                maxWidth: "440px",
                padding: "1.75rem",
                backgroundColor: "var(--bg-secondary)",
                textAlign: "center",
              }}
            >
              <h3 style={{ fontSize: "1.2rem", fontWeight: "700", marginBottom: "0.5rem" }}>
                Mã VietQR Nhắc Đóng Học Phí
              </h3>
              <p style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginBottom: "1.25rem" }}>
                Phụ huynh quét mã bên dưới để chuyển khoản chính xác số tiền nợ
              </p>

              <div style={{ background: "#ffffff", padding: "1rem", borderRadius: "16px", display: "inline-block", marginBottom: "1rem" }}>
                <img
                  src={`https://img.vietqr.io/image/${bin}-${stk}-compact2.png?amount=${selectedQr.sotien}&addInfo=${encodeURIComponent(selectedQr.noidung)}&accountName=${encodeURIComponent(ctk)}`}
                  alt="VietQR"
                  style={{ width: "250px", height: "250px", display: "block" }}
                />
              </div>

              <div style={{ textAlign: "left", backgroundColor: "var(--bg-primary)", padding: "0.85rem", borderRadius: "8px", fontSize: "0.85rem", marginBottom: "1.25rem", display: "flex", flexDirection: "column", gap: "0.35rem" }}>
                <div><strong>Ngân hàng:</strong> {bankName} (Mã BIN: {bin})</div>
                <div><strong>Số tài khoản:</strong> <span style={{ color: "var(--accent-primary)", fontWeight: "700" }}>{stk}</span></div>
                <div><strong>Chủ tài khoản:</strong> <strong>{ctk}</strong></div>
                <hr style={{ borderColor: "var(--border-color)", margin: "0.25rem 0" }} />
                <div><strong>Học sinh:</strong> {selectedQr.ten}</div>
                <div><strong>Số tiền nợ:</strong> <span style={{ color: "var(--danger)", fontWeight: "700" }}>{formatCurrency(selectedQr.sotien)}</span></div>
                <div><strong>Nội dung CK:</strong> <span style={{ fontFamily: "monospace", color: "var(--warning)" }}>{selectedQr.noidung}</span></div>
              </div>

              <button onClick={() => setSelectedQr(null)} className="btn-primary" style={{ width: "100%", justifyContent: "center" }}>
                Đóng
              </button>
            </div>
          </div>
        );
      })()}
    </div>
  );
}
