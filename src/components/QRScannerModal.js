"use client";

import React, { useEffect, useRef, useState } from "react";
import { Html5Qrcode } from "html5-qrcode";
import { Camera, X, ShieldAlert, Sparkles, CheckCircle2 } from "lucide-react";

export default function QRScannerModal({ onClose, onScanSuccess }) {
  const [scanError, setScanError] = useState("");
  const [isScanning, setIsScanning] = useState(true);
  const scannerRef = useRef(null);

  useEffect(() => {
    let html5QrCode = null;

    const startScanner = async () => {
      try {
        html5QrCode = new Html5Qrcode("qr-reader-container");
        scannerRef.current = html5QrCode;

        await html5QrCode.start(
          { facingMode: "environment" }, // Rear camera if on mobile
          {
            fps: 10,
            qrbox: { width: 250, height: 250 },
          },
          (decodedText) => {
            // QR Code Scanned Successfully!
            if (html5QrCode && html5QrCode.isScanning) {
              html5QrCode.stop().catch((e) => console.error(e));
            }
            setIsScanning(false);
            onScanSuccess(decodedText);
          },
          (errorMessage) => {
            // Ignore frame-by-frame decode failure
          }
        );
      } catch (err) {
        console.error("Lỗi khởi chạy camera QR:", err);
        setScanError("Không thể bật Camera. Vui lòng cho phép quyền truy cập Camera trên trình duyệt!");
      }
    };

    startScanner();

    return () => {
      if (scannerRef.current && scannerRef.current.isScanning) {
        scannerRef.current.stop().catch((e) => console.error(e));
      }
    };
  }, [onScanSuccess]);

  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        backgroundColor: "rgba(0, 0, 0, 0.85)",
        backdropFilter: "blur(8px)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        zIndex: 130,
        padding: "1rem",
      }}
    >
      <div
        style={{
          backgroundColor: "var(--bg-card)",
          borderRadius: "var(--radius-lg)",
          border: "1px solid var(--border-color)",
          width: "100%",
          maxWidth: "450px",
          padding: "1.5rem",
          textAlign: "center",
          boxShadow: "0 10px 40px rgba(0,0,0,0.5)",
          position: "relative",
        }}
      >
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
          <X size={22} />
        </button>

        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: "0.5rem", marginBottom: "0.4rem" }}>
          <Camera size={24} color="var(--accent-primary)" />
          <h3 style={{ fontSize: "1.2rem", fontWeight: "800" }}>Quét Mã QR Thẻ Học Sinh</h3>
        </div>
        <p style={{ fontSize: "0.82rem", color: "var(--text-muted)", marginBottom: "1.25rem" }}>
          Đưa mã QR trên thẻ học sinh trước ống kính camera để tự động đăng nhập
        </p>

        {scanError ? (
          <div
            style={{
              backgroundColor: "rgba(239, 68, 68, 0.15)",
              border: "1px solid rgba(239, 68, 68, 0.3)",
              color: "var(--danger)",
              padding: "1rem",
              borderRadius: "12px",
              fontSize: "0.85rem",
              marginBottom: "1rem",
              fontWeight: "600",
            }}
          >
            <ShieldAlert size={28} style={{ marginBottom: "0.5rem" }} />
            <div>{scanError}</div>
          </div>
        ) : (
          <div
            style={{
              position: "relative",
              borderRadius: "16px",
              overflow: "hidden",
              border: "2px solid var(--accent-primary)",
              marginBottom: "1rem",
              backgroundColor: "#000000",
              minHeight: "280px",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <div id="qr-reader-container" style={{ width: "100%" }} />
          </div>
        )}

        <button
          type="button"
          onClick={onClose}
          className="btn-secondary"
          style={{ width: "100%", padding: "0.65rem", fontWeight: "600" }}
        >
          Đóng Camera Scanner
        </button>
      </div>
    </div>
  );
}
