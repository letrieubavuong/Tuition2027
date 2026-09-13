"use client";

import React, { useEffect, useState } from "react";
import QRCode from "qrcode";
import { QrCode, Download, Printer, X, GraduationCap, CheckCircle } from "lucide-react";

export default function StudentQRModal({ student, onClose }) {
  const [qrSrc, setQrSrc] = useState("");
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!student) return;

    // Construct Student QR Payload
    const qrPayload = JSON.stringify({
      type: "TUITION_STUDENT_QR",
      id: student.id || student._key,
      name: student.ten || student.ho_ten || "Học sinh",
      phone: student.sdt_phuhuynh || student.sdt || "",
      classId: student.lop_id || student.lop || "",
      className: student.ten_lop || "Lớp học",
    });

    QRCode.toDataURL(
      qrPayload,
      {
        width: 300,
        margin: 2,
        color: {
          dark: "#0f172a",
          light: "#ffffff",
        },
      },
      (err, url) => {
        if (err) console.error("Lỗi tạo mã QR:", err);
        else setQrSrc(url);
      }
    );
  }, [student]);

  if (!student) return null;

  const handleDownloadQR = () => {
    if (!qrSrc) return;
    const a = document.createElement("a");
    a.href = qrSrc;
    a.download = `Ma_QR_${(student.ten || "hoc_sinh").replace(/\s+/g, "_")}.png`;
    a.click();
  };

  const handleCopyLink = () => {
    const loginLink = `${window.location.origin}/login?qr_user=${encodeURIComponent(
      student.id || student._key
    )}&name=${encodeURIComponent(student.ten || "")}`;
    navigator.clipboard.writeText(loginLink);
    setCopied(true);
    setTimeout(() => setCopied(false), 3000);
  };

  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        backgroundColor: "rgba(0, 0, 0, 0.75)",
        backdropFilter: "blur(6px)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        zIndex: 120,
        padding: "1rem",
      }}
    >
      <div
        style={{
          backgroundColor: "var(--bg-card)",
          borderRadius: "var(--radius-lg)",
          border: "1px solid var(--border-color)",
          width: "100%",
          maxWidth: "420px",
          padding: "1.75rem",
          textAlign: "center",
          boxShadow: "0 10px 40px rgba(0,0,0,0.3)",
          position: "relative",
        }}
      >
        {/* Close Button */}
        <button
          type="button"
          onClick={onClose}
          style={{
            position: "absolute",
            top: "1rem",
            right: "1rem",
            background: "none",
            border: "none",
            color: "var(--text-muted)",
            cursor: "pointer",
          }}
        >
          <X size={20} />
        </button>

        {/* Title */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: "0.5rem", marginBottom: "0.5rem" }}>
          <QrCode size={24} color="var(--accent-primary)" />
          <h3 style={{ fontSize: "1.2rem", fontWeight: "800" }}>Mã QR Thẻ Học Sinh</h3>
        </div>
        <p style={{ fontSize: "0.82rem", color: "var(--text-muted)", marginBottom: "1.25rem" }}>
          Quét mã này bằng camera điện thoại để đăng nhập nhanh làm bài thi
        </p>

        {/* Card Frame for Printing */}
        <div
          id="student-qr-card"
          style={{
            backgroundColor: "var(--bg-secondary)",
            padding: "1.25rem",
            borderRadius: "16px",
            border: "2px solid var(--border-color)",
            marginBottom: "1.25rem",
          }}
        >
          <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: "0.5rem", marginBottom: "0.75rem" }}>
            <GraduationCap size={20} color="var(--accent-primary)" />
            <span style={{ fontSize: "0.78rem", fontWeight: "800", color: "var(--accent-primary)", letterSpacing: "0.5px" }}>
              141 NGUYỄN THIỆN KẾ - THẺ HỌC SINH
            </span>
          </div>

          <h4 style={{ fontSize: "1.25rem", fontWeight: "800", color: "var(--text-primary)", marginBottom: "0.25rem" }}>
            {student.ten || student.ho_ten}
          </h4>

          <p style={{ fontSize: "0.85rem", color: "var(--text-muted)", marginBottom: "1rem" }}>
            Mã HS: <strong>#{student.id || student._key}</strong> | Lớp: <strong>{student.ten_lop || "Lớp 9A1"}</strong>
          </p>

          {/* QR Image Container */}
          <div
            style={{
              backgroundColor: "#ffffff",
              padding: "0.75rem",
              borderRadius: "12px",
              display: "inline-block",
              boxShadow: "0 4px 15px rgba(0,0,0,0.1)",
            }}
          >
            {qrSrc ? (
              <img src={qrSrc} alt="Mã QR Học sinh" style={{ width: "190px", height: "190px", display: "block" }} />
            ) : (
              <div style={{ width: "190px", height: "190px", display: "flex", alignItems: "center", justifyContent: "center", color: "#666" }}>
                Đang tạo QR...
              </div>
            )}
          </div>
        </div>

        {/* Action Buttons */}
        <div style={{ display: "flex", flexDirection: "column", gap: "0.6rem" }}>
          <button
            type="button"
            onClick={handleDownloadQR}
            className="btn-primary"
            style={{
              width: "100%",
              padding: "0.75rem",
              borderRadius: "var(--radius-md)",
              fontWeight: "700",
              fontSize: "0.9rem",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              gap: "0.5rem",
            }}
          >
            <Download size={18} /> Tải Ảnh Mã QR Về Máy
          </button>

          <button
            type="button"
            onClick={handleCopyLink}
            className="btn-secondary"
            style={{
              width: "100%",
              padding: "0.7rem",
              borderRadius: "var(--radius-md)",
              fontWeight: "600",
              fontSize: "0.85rem",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              gap: "0.5rem",
            }}
          >
            {copied ? <CheckCircle size={16} color="var(--success)" /> : <QrCode size={16} />}
            {copied ? "Đã Sao Chép Link Đăng Nhập QR!" : "Sao Chép Link Đăng Nhập Nhanh"}
          </button>
        </div>
      </div>
    </div>
  );
}
