"use client";

import { useEffect, useState } from "react";
import { db, ref, onValue, set } from "@/lib/firebase";
import { CreditCard, CheckCircle2, AlertTriangle, QrCode, Search, DollarSign, Calendar, Filter, Phone, Users, BookOpen, X, PlusCircle, FileText } from "lucide-react";

export default function HocPhiPage() {
  const [rawPayments, setRawPayments] = useState([]);
  const [payments, setPayments] = useState([]);
  const [studentsMap, setStudentsMap] = useState({});
  const [classesList, setClassesList] = useState([]);
  const [classesMap, setClassesMap] = useState({});
  const [studentClasses, setStudentClasses] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("all"); // all, paid, debt
  const [selectedMonth, setSelectedMonth] = useState("all");
  const [selectedClass, setSelectedClass] = useState("all");
  const [availableMonths, setAvailableMonths] = useState([]);
  const [selectedQr, setSelectedQr] = useState(null);
  const [paymentModal, setPaymentModal] = useState(null);
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
        setRawPayments(rawList);
      } else {
        setRawPayments([]);
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

    // 4. Lắng nghe cả 2 node lớp học 'lop' và 'lop_hoc' từ Firebase Realtime Database
    let listLop1 = [];
    let listLop2 = [];

    const mergeAllClasses = () => {
      const combined = [...listLop1, ...listLop2];
      const classMapById = new Map();
      const cMap = {};

      combined.forEach((c) => {
        const key = String(c.id ?? c._key ?? "");
        const name = c.ten_lop || c.ten || (key ? `Lớp #${key}` : "");
        if (key && name) {
          classMapById.set(key, { id: key, name });
          cMap[key] = name;
        }
      });

      // Bổ sung các lớp xuất hiện trong thanh toán (thanh_toan)
      payments.forEach((p) => {
        const cId = String(p.id_lop ?? p.lop_id ?? "");
        const cName = p.ten_lop;
        if (cId && cId !== "ALL" && !classMapById.has(cId)) {
          const displayName = cName || `Lớp #${cId}`;
          classMapById.set(cId, { id: cId, name: displayName });
          cMap[cId] = displayName;
        } else if (cName && cName.trim() !== "" && !classMapById.has(cName)) {
          classMapById.set(cName, { id: cName, name: cName });
          cMap[cName] = cName;
        }
      });

      const resultList = Array.from(classMapById.values()).sort((a, b) =>
        a.name.localeCompare(b.name, "vi")
      );
      setClassesList(resultList);
      setClassesMap(cMap);
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
      mergeAllClasses();
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
      mergeAllClasses();
    });

    // 5. Lắng nghe quan hệ lớp - học sinh
    const lhsRef = ref(db, "lop_hoc_sinh");
    const unsubLhs = onValue(lhsRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = Array.isArray(val)
          ? val.map((item, idx) => (item ? { ...item, _key: item.id || idx } : null)).filter(Boolean)
          : Object.entries(val).map(([k, v]) => ({ ...v, _key: k }));
        setStudentClasses(list);
      } else {
        setStudentClasses([]);
      }
    });

    return () => {
      unsubHs();
      unsubPay();
      unsubBank();
      unsubLop1();
      unsubLop2();
      unsubLhs();
    };
  }, []);

  // Deduplicate payment records whenever rawPayments or classesMap changes
  useEffect(() => {
    if (!rawPayments || rawPayments.length === 0) {
      setPayments([]);
      setAvailableMonths([]);
      return;
    }

    const payMap = new Map();
    rawPayments.forEach((p) => {
      const hsId = p.id_hoc_sinh ?? p.hoc_sinh_id;
      const monthKey = p.thang ?? p.month ?? "UNKNOWN";

      // Normalize class identifier to canonical class name if mapped in classesMap
      let lopIdKey = "ALL";
      const rawLopId = p.id_lop ?? p.lop_id;
      const rawTenLop = (p.ten_lop || "").trim();

      if (rawLopId !== undefined && rawLopId !== null && rawLopId !== "ALL" && String(rawLopId).trim() !== "") {
        lopIdKey = classesMap[rawLopId] || classesMap[String(rawLopId)] || rawTenLop || String(rawLopId);
      } else if (rawTenLop) {
        lopIdKey = rawTenLop;
      }

      const uniqueKey = (hsId !== undefined && monthKey)
        ? `${hsId}_${lopIdKey}_${monthKey}`
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

    // Mặc định chọn tháng mới nhất nếu chưa có tháng nào được chọn
    if (months.length > 0 && selectedMonth === "all") {
      setSelectedMonth(months[0]);
    }
  }, [rawPayments, classesMap]);

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

  const openPaymentModal = (p) => {
    const studentName = getStudentName(p);
    const className = getPaymentClassName(p);
    const daDong = Number(p.so_tien_da_dong) || 0;
    const tong = Number(p.tong_thanh_toan) || 0;
    const conNo = Math.max(0, tong - daDong);
    const initialCollect = conNo > 0 ? conNo : 0;

    setPaymentModal({
      payment: p,
      studentName,
      className,
      month: p.thang,
      tong,
      daDong,
      conNo,
      collectAmount: initialCollect,
      extraFee: 0,
      extraReason: "",
      note: p.ghi_chu || "",
      paymentDate: new Date().toISOString().split("T")[0],
    });
  };

  const handleConfirmPayment = async (modalData) => {
    try {
      const p = modalData.payment;
      const currentPaid = Number(p.so_tien_da_dong) || 0;
      const addPaid = Number(modalData.collectAmount) || 0;
      const newPaid = currentPaid + addPaid;
      const extraFee = Number(modalData.extraFee) || 0;

      let finalNote = modalData.note ? modalData.note.trim() : "";
      if (extraFee > 0) {
        const extraDesc = modalData.extraReason.trim() ? modalData.extraReason.trim() : "Phát sinh";
        finalNote = finalNote
          ? `${finalNote} | +${extraFee.toLocaleString("vi-VN")}đ (${extraDesc})`
          : `+${extraFee.toLocaleString("vi-VN")}đ (${extraDesc})`;
      }

      const pRef = ref(db, `thanh_toan/${p._key}`);
      await set(pRef, {
        ...p,
        so_tien_da_dong: newPaid,
        ngay_thanh_toan: modalData.paymentDate || new Date().toISOString().split("T")[0],
        ghi_chu: finalNote || p.ghi_chu || "",
        updated_at: new Date().toISOString(),
      });

      setPaymentModal(null);
      alert(`Đã thu thành công ${addPaid.toLocaleString("vi-VN")} VNĐ của ${modalData.studentName}!`);
    } catch (err) {
      alert("Lỗi thanh toán: " + err.message);
    }
  };

  const getPaymentClassName = (p) => {
    if (p.ten_lop && p.ten_lop.trim() !== "") return p.ten_lop;
    const lopId = p.id_lop ?? p.lop_id;
    if (lopId && classesMap[lopId]) return classesMap[lopId];
    if (lopId && classesMap[String(lopId)]) return classesMap[String(lopId)];

    const hsId = p.id_hoc_sinh ?? p.hoc_sinh_id;
    if (hsId !== undefined) {
      const enrolled = studentClasses.filter(
        (lhs) => String(lhs.id_hoc_sinh || lhs.hoc_sinh_id) === String(hsId) && (lhs.trang_thai || "DANG_HOC") === "DANG_HOC"
      );
      const names = enrolled
        .map((lhs) => {
          const cId = lhs.id_lop || lhs.lop_id;
          return classesMap[cId] || classesMap[String(cId)];
        })
        .filter(Boolean);
      if (names.length > 0) return names.join(", ");
    }
    return "";
  };

  const isPaymentInSelectedClass = (p) => {
    if (selectedClass === "all") return true;

    const selectedClassName = classesMap[selectedClass] || String(selectedClass);
    const payLopId = String(p.id_lop ?? p.lop_id ?? "");
    const payLopName = (p.ten_lop || "").trim();

    // 1. If the payment record itself specifies a class:
    if (payLopId && payLopId !== "ALL") {
      const pClassName = classesMap[payLopId] || payLopId;
      return (
        payLopId === String(selectedClass) ||
        pClassName === selectedClassName ||
        pClassName === String(selectedClass)
      );
    }

    if (payLopName) {
      return (
        payLopName === String(selectedClass) ||
        payLopName === selectedClassName
      );
    }

    // 2. Only if payment record does NOT specify a class (generic record), fallback to checking student enrollment:
    const hsId = p.id_hoc_sinh ?? p.hoc_sinh_id;
    if (hsId !== undefined) {
      const isEnrolled = studentClasses.some((lhs) => {
        const lhsHsId = String(lhs.id_hoc_sinh || lhs.hoc_sinh_id || "");
        const lhsLopId = String(lhs.id_lop || lhs.lop_id || "");
        const lhsLopName = classesMap[lhsLopId] || lhsLopId;
        return (
          lhsHsId === String(hsId) &&
          (lhsLopId === String(selectedClass) || lhsLopName === selectedClassName)
        );
      });
      return isEnrolled;
    }

    return false;
  };

  // Base list filtered by Search, Month, and Class (used for top summary statistics)
  const classAndMonthPayments = payments.filter((p) => {
    const sName = getStudentName(p);
    const cName = getPaymentClassName(p);
    const matchesSearch =
      !searchQuery ||
      (sName && sName.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (cName && cName.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (p.thang && p.thang.includes(searchQuery));

    const matchesMonth = selectedMonth === "all" || p.thang === selectedMonth;
    const matchesClass = isPaymentInSelectedClass(p);

    return matchesMonth && matchesClass && matchesSearch;
  });

  // Table list filtered further by status tab (paid / debt / all)
  const filteredPayments = classAndMonthPayments.filter((p) => {
    const daDong = Number(p.so_tien_da_dong) || 0;
    const tong = Number(p.tong_thanh_toan) || 0;
    const isPaid = daDong >= tong && tong > 0;

    if (statusFilter === "paid") return isPaid;
    if (statusFilter === "debt") return !isPaid;
    return true;
  });

  // Calculate top summary stats based on classAndMonthPayments (unaffected by table status tab)
  const totalMonthAmount = classAndMonthPayments.reduce((sum, p) => sum + (Number(p.tong_thanh_toan) || 0), 0);
  const totalMonthPaid = classAndMonthPayments.reduce((sum, p) => sum + (Number(p.so_tien_da_dong) || 0), 0);
  const totalMonthDebt = classAndMonthPayments.reduce((sum, p) => {
    const tong = Number(p.tong_thanh_toan) || 0;
    const daDong = Number(p.so_tien_da_dong) || 0;
    return sum + (tong > daDong ? tong - daDong : 0);
  }, 0);
  const completionRate = totalMonthAmount > 0 ? Math.min(100, (totalMonthPaid / totalMonthAmount) * 100) : 100;

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

          {/* Class Dropdown Selector */}
          <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <Users size={18} color="#8b5cf6" />
            <span style={{ fontSize: "0.9rem", fontWeight: "600" }}>Lớp:</span>
            <select
              value={selectedClass}
              onChange={(e) => setSelectedClass(e.target.value)}
              className="input-control"
              style={{ padding: "0.6rem 1rem", fontSize: "0.9rem", fontWeight: "600", cursor: "pointer", minWidth: "160px" }}
            >
              <option value="all">🏫 Tất cả các lớp ({classesList.length})</option>
              {classesList.map((c) => (
                <option key={c.id} value={c.id}>
                  📚 {c.name}
                </option>
              ))}
            </select>
          </div>

          {/* Month Dropdown Selector */}
          <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <Calendar size={18} color="var(--accent-primary)" />
            <span style={{ fontSize: "0.9rem", fontWeight: "600" }}>Tháng:</span>
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

        {/* Monthly Summary Bar & Progress Bar */}
        <div
          style={{
            marginTop: "1.25rem",
            paddingTop: "1.25rem",
            borderTop: "1px solid var(--border-color)",
          }}
        >
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))",
              gap: "1rem",
              marginBottom: "1rem",
            }}
          >
            <div style={{ backgroundColor: "rgba(255,255,255,0.03)", padding: "0.85rem 1rem", borderRadius: "10px", border: "1px solid rgba(255,255,255,0.06)" }}>
              <span style={{ fontSize: "0.78rem", color: "var(--text-muted)", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.5px" }}>PHẢI THU (TỔNG CẦN THU)</span>
              <div style={{ fontSize: "1.35rem", fontWeight: "800", marginTop: "0.2rem", color: "var(--text-primary)" }}>{formatCurrency(totalMonthAmount)}</div>
            </div>
            <div style={{ backgroundColor: "rgba(16, 185, 129, 0.08)", padding: "0.85rem 1rem", borderRadius: "10px", border: "1px solid rgba(16, 185, 129, 0.2)" }}>
              <span style={{ fontSize: "0.78rem", color: "#10b981", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.5px" }}>ĐÃ THU</span>
              <div style={{ fontSize: "1.35rem", fontWeight: "800", marginTop: "0.2rem", color: "#10b981" }}>{formatCurrency(totalMonthPaid)}</div>
            </div>
            <div style={{ backgroundColor: totalMonthDebt > 0 ? "rgba(239, 68, 68, 0.08)" : "rgba(255,255,255,0.03)", padding: "0.85rem 1rem", borderRadius: "10px", border: totalMonthDebt > 0 ? "1px solid rgba(239, 68, 68, 0.25)" : "1px solid rgba(255,255,255,0.06)" }}>
              <span style={{ fontSize: "0.78rem", color: totalMonthDebt > 0 ? "#ef4444" : "var(--text-muted)", fontWeight: "600", textTransform: "uppercase", letterSpacing: "0.5px" }}>CÒN NỢ</span>
              <div style={{ fontSize: "1.35rem", fontWeight: "800", marginTop: "0.2rem", color: totalMonthDebt > 0 ? "#ef4444" : "var(--text-muted)" }}>{formatCurrency(totalMonthDebt)}</div>
            </div>
          </div>

          {/* Completion Progress Bar */}
          <div>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0.35rem", fontSize: "0.82rem" }}>
              <span style={{ color: "var(--text-secondary)", fontWeight: "600" }}>Tỷ lệ hoàn thành thu học phí</span>
              <span style={{ fontWeight: "700", color: completionRate === 100 ? "#10b981" : "var(--accent-primary)" }}>{completionRate.toFixed(1)}%</span>
            </div>
            <div style={{ width: "100%", height: "8px", backgroundColor: "rgba(255,255,255,0.08)", borderRadius: "4px", overflow: "hidden" }}>
              <div
                style={{
                  width: `${completionRate}%`,
                  height: "100%",
                  background: completionRate === 100 ? "#10b981" : "linear-gradient(90deg, var(--accent-primary), #10b981)",
                  borderRadius: "4px",
                  transition: "width 0.4s ease",
                }}
              />
            </div>
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
                  <th>Lớp Học</th>
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
                        {getPaymentClassName(p) ? (
                          <span
                            style={{
                              fontSize: "0.75rem",
                              fontWeight: "600",
                              padding: "0.2rem 0.55rem",
                              borderRadius: "4px",
                              backgroundColor: "rgba(139, 92, 246, 0.15)",
                              color: "#a78bfa",
                              border: "1px solid rgba(139, 92, 246, 0.3)",
                            }}
                          >
                            {getPaymentClassName(p)}
                          </span>
                        ) : (
                          <span style={{ color: "var(--text-muted)", fontSize: "0.8rem" }}>--</span>
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
                                let clean = studentPhone.replace(/[^0-9]/g, "");
                                if (clean.startsWith("0")) {
                                  clean = "84" + clean.slice(1);
                                }
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
                            onClick={() => openPaymentModal(p)}
                            className="btn-primary"
                            style={{
                              padding: "0.4rem 0.75rem",
                              fontSize: "0.8rem",
                              fontWeight: "700",
                              display: "inline-flex",
                              alignItems: "center",
                              gap: "0.3rem",
                              backgroundColor: "#10b981",
                              borderColor: "#10b981",
                              boxShadow: "0 2px 8px rgba(16, 185, 129, 0.3)",
                            }}
                            title="Mở dialog thu tiền học phí"
                          >
                            <DollarSign size={14} /> Thanh toán
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

      {/* Payment Dialog Modal (ThuTienHocPhiDialog - Giống App) */}
      {paymentModal && (
        <div
          style={{
            position: "fixed",
            inset: 0,
            backgroundColor: "rgba(0, 0, 0, 0.65)",
            backdropFilter: "blur(5px)",
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
              maxWidth: "480px",
              padding: "1.75rem",
              backgroundColor: "var(--bg-secondary)",
              borderRadius: "16px",
              boxShadow: "0 20px 40px rgba(0, 0, 0, 0.4)",
              maxHeight: "90vh",
              overflowY: "auto",
            }}
          >
            {/* Header */}
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem", borderBottom: "1px solid var(--border-color)", paddingBottom: "0.75rem" }}>
              <div>
                <h3 style={{ fontSize: "1.3rem", fontWeight: "800", color: "var(--text-primary)" }}>
                  💳 Thu Tiền Học Phí
                </h3>
                <div style={{ fontSize: "0.85rem", color: "var(--accent-primary)", fontWeight: "600", marginTop: "0.15rem" }}>
                  {paymentModal.studentName} {paymentModal.className ? `• ${paymentModal.className}` : ""}
                </div>
              </div>
              <button
                onClick={() => setPaymentModal(null)}
                style={{ background: "none", border: "none", color: "var(--text-muted)", cursor: "pointer", padding: "0.25rem" }}
              >
                <X size={20} />
              </button>
            </div>

            {/* Summary Box */}
            <div style={{ backgroundColor: "var(--bg-primary)", padding: "0.85rem 1rem", borderRadius: "10px", marginBottom: "1.25rem", border: "1px solid var(--border-color)" }}>
              <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.88rem", marginBottom: "0.4rem" }}>
                <span style={{ color: "var(--text-secondary)" }}>Tháng đóng:</span>
                <span className="badge badge-info">Tháng {formatMonthYear(paymentModal.month)}</span>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.88rem", marginBottom: "0.4rem" }}>
                <span style={{ color: "var(--text-secondary)" }}>Học phí cần nộp:</span>
                <span style={{ fontWeight: "700" }}>{formatCurrency(paymentModal.tong)}</span>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.88rem", marginBottom: "0.4rem" }}>
                <span style={{ color: "var(--text-secondary)" }}>Đã đóng trước đó:</span>
                <span style={{ color: "var(--success)", fontWeight: "700" }}>{formatCurrency(paymentModal.daDong)}</span>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.95rem", paddingTop: "0.4rem", borderTop: "1px dashed var(--border-color)" }}>
                <span style={{ fontWeight: "700", color: "var(--text-primary)" }}>Còn nợ thực tế:</span>
                <span style={{ color: paymentModal.conNo > 0 ? "var(--danger)" : "var(--success)", fontWeight: "800" }}>{formatCurrency(paymentModal.conNo)}</span>
              </div>
            </div>

            {/* Quick Amount Presets (Đóng đủ 100% / 50%) */}
            {paymentModal.conNo > 0 && (
              <div style={{ display: "flex", gap: "0.5rem", marginBottom: "1rem" }}>
                <button
                  type="button"
                  onClick={() =>
                    setPaymentModal({
                      ...paymentModal,
                      collectAmount: paymentModal.conNo,
                    })
                  }
                  style={{
                    flex: 1,
                    padding: "0.5rem",
                    borderRadius: "8px",
                    border: "1px solid var(--accent-primary)",
                    backgroundColor: "rgba(13, 148, 136, 0.12)",
                    color: "var(--accent-primary)",
                    fontWeight: "700",
                    fontSize: "0.8rem",
                    cursor: "pointer",
                  }}
                >
                  ✅ Đóng đủ (100%): {formatCurrency(paymentModal.conNo)}
                </button>
                <button
                  type="button"
                  onClick={() =>
                    setPaymentModal({
                      ...paymentModal,
                      collectAmount: Math.round(paymentModal.conNo / 2),
                    })
                  }
                  style={{
                    flex: 1,
                    padding: "0.5rem",
                    borderRadius: "8px",
                    border: "1px solid var(--border-color)",
                    backgroundColor: "rgba(255, 255, 255, 0.05)",
                    color: "var(--text-primary)",
                    fontWeight: "600",
                    fontSize: "0.8rem",
                    cursor: "pointer",
                  }}
                >
                  🌗 Nửa tháng (50%): {formatCurrency(Math.round(paymentModal.conNo / 2))}
                </button>
              </div>
            )}

            {/* Form Controls */}
            <form
              onSubmit={(e) => {
                e.preventDefault();
                handleConfirmPayment(paymentModal);
              }}
              style={{ display: "flex", flexDirection: "column", gap: "0.9rem" }}
            >
              {/* Số tiền thu thêm */}
              <div>
                <label style={{ display: "block", fontSize: "0.82rem", fontWeight: "700", marginBottom: "0.3rem", color: "var(--text-primary)" }}>
                  💵 Số tiền thu lần này (VNĐ):
                </label>
                <input
                  type="number"
                  value={paymentModal.collectAmount}
                  onChange={(e) =>
                    setPaymentModal({
                      ...paymentModal,
                      collectAmount: e.target.value,
                    })
                  }
                  className="input-control"
                  style={{ width: "100%", fontSize: "1.1rem", fontWeight: "800", color: "#10b981" }}
                  min="0"
                  required
                />
                <div style={{ fontSize: "0.78rem", color: "var(--text-muted)", marginTop: "0.25rem" }}>
                  Tổng đã đóng sau khi thu: <strong style={{ color: "#10b981" }}>{formatCurrency(paymentModal.daDong + (Number(paymentModal.collectAmount) || 0))}</strong>
                </div>
              </div>

              {/* Thu thêm phát sinh khác */}
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0.6rem" }}>
                <div>
                  <label style={{ display: "block", fontSize: "0.8rem", fontWeight: "600", marginBottom: "0.3rem", color: "var(--text-secondary)" }}>
                    ➕ Thu thêm (Sách, TL...):
                  </label>
                  <input
                    type="number"
                    value={paymentModal.extraFee}
                    onChange={(e) =>
                      setPaymentModal({
                        ...paymentModal,
                        extraFee: e.target.value,
                      })
                    }
                    className="input-control"
                    style={{ width: "100%", fontSize: "0.9rem" }}
                    placeholder="0"
                    min="0"
                  />
                </div>
                <div>
                  <label style={{ display: "block", fontSize: "0.8rem", fontWeight: "600", marginBottom: "0.3rem", color: "var(--text-secondary)" }}>
                    Lý do thu thêm:
                  </label>
                  <input
                    type="text"
                    value={paymentModal.extraReason}
                    onChange={(e) =>
                      setPaymentModal({
                        ...paymentModal,
                        extraReason: e.target.value,
                      })
                    }
                    className="input-control"
                    style={{ width: "100%", fontSize: "0.9rem" }}
                    placeholder="Ví dụ: Tiền giáo trình"
                  />
                </div>
              </div>

              {/* Ngày thanh toán */}
              <div>
                <label style={{ display: "block", fontSize: "0.8rem", fontWeight: "600", marginBottom: "0.3rem", color: "var(--text-secondary)" }}>
                  📅 Ngày thu tiền:
                </label>
                <input
                  type="date"
                  value={paymentModal.paymentDate}
                  onChange={(e) =>
                    setPaymentModal({
                      ...paymentModal,
                      paymentDate: e.target.value,
                    })
                  }
                  className="input-control"
                  style={{ width: "100%", fontSize: "0.9rem" }}
                  required
                />
              </div>

              {/* Ghi chú */}
              <div>
                <label style={{ display: "block", fontSize: "0.8rem", fontWeight: "600", marginBottom: "0.3rem", color: "var(--text-secondary)" }}>
                  📝 Ghi chú:
                </label>
                <input
                  type="text"
                  value={paymentModal.note}
                  onChange={(e) =>
                    setPaymentModal({
                      ...paymentModal,
                      note: e.target.value,
                    })
                  }
                  className="input-control"
                  style={{ width: "100%", fontSize: "0.9rem" }}
                  placeholder="Nhập ghi chú thanh toán (nếu có)..."
                />
              </div>

              {/* Modal Action Buttons */}
              <div style={{ display: "flex", gap: "0.6rem", marginTop: "0.5rem" }}>
                {paymentModal.conNo > 0 && (
                  <button
                    type="button"
                    onClick={() => {
                      const p = paymentModal.payment;
                      const studentName = paymentModal.studentName;
                      const conNo = paymentModal.conNo;
                      setSelectedQr({
                        ten: studentName,
                        sotien: Number(paymentModal.collectAmount) > 0 ? Number(paymentModal.collectAmount) : conNo,
                        noidung: `HOCPHI THANG ${formatMonthYear(p.thang)} ${studentName}`,
                      });
                    }}
                    className="btn-secondary"
                    style={{ padding: "0.65rem 0.85rem", fontSize: "0.85rem", color: "var(--accent-primary)" }}
                  >
                    <QrCode size={16} /> VietQR
                  </button>
                )}

                <button
                  type="button"
                  onClick={() => setPaymentModal(null)}
                  className="btn-secondary"
                  style={{ flex: 1, justifyContent: "center" }}
                >
                  Hủy
                </button>

                <button
                  type="submit"
                  className="btn-primary"
                  style={{
                    flex: 1.5,
                    justifyContent: "center",
                    backgroundColor: "#10b981",
                    borderColor: "#10b981",
                    fontWeight: "700",
                    boxShadow: "0 4px 12px rgba(16, 185, 129, 0.35)",
                  }}
                >
                  <CheckCircle2 size={16} /> Xác nhận Thu tiền
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
