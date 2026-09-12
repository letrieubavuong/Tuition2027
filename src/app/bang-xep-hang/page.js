"use client";

import { useEffect, useState } from "react";
import { db, ref, onValue } from "@/lib/firebase";
import { Trophy, Medal, Award, Crown, Star, Users, Search } from "lucide-react";

export default function BangXepHangPage() {
  const [students, setStudents] = useState([]);
  const [classes, setClasses] = useState([]);
  const [ratings, setRatings] = useState([]);
  const [selectedFilter, setSelectedFilter] = useState("ALL");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Fetch students
    const hsRef = ref(db, "hoc_sinh");
    const unsubHs = onValue(hsRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = Array.isArray(val)
          ? val.map((item, idx) => (item ? { ...item, _key: item.id || idx } : null)).filter(Boolean)
          : Object.entries(val).map(([k, v]) => ({ ...v, _key: k }));
        setStudents(list);
      }
    });

    // Fetch classes
    const lopRef = ref(db, "lop_hoc");
    const unsubLop = onValue(lopRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = Array.isArray(val)
          ? val.map((item, idx) => (item ? { ...item, _key: item.id || idx } : null)).filter(Boolean)
          : Object.entries(val).map(([k, v]) => ({ ...v, _key: k }));
        setClasses(list);
      }
    });

    // Fetch ratings & bonus points
    const dgRef = ref(db, "danh_gia_buoi_hoc");
    const unsubDg = onValue(dgRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        setRatings(list);
      }
      setLoading(false);
    });

    return () => {
      unsubHs();
      unsubLop();
      unsubDg();
    };
  }, []);

  // Compute accumulated points for each student
  const studentScores = students.map((s) => {
    const sid = String(s.id || s._key);
    let totalPoints = Number(s.diem_thuong) || Number(s.diem) || 0;

    // Aggregate bonus points from ratings log
    ratings.forEach((r) => {
      if (r.danh_gia && r.danh_gia[sid]) {
        const item = r.danh_gia[sid];
        if (item.diem_thuong) totalPoints += Number(item.diem_thuong);
        if (item.diem_kt) totalPoints += Number(item.diem_kt);
      }
    });

    return {
      ...s,
      calculatedScore: totalPoints,
    };
  });

  // Sort descending by score
  const sortedStudents = [...studentScores].sort(
    (a, b) => b.calculatedScore - a.calculatedScore
  );

  const top1 = sortedStudents[0];
  const top2 = sortedStudents[1];
  const top3 = sortedStudents[2];

  return (
    <div>
      {/* Header */}
      <div style={{ marginBottom: "1.75rem" }}>
        <h2 style={{ fontSize: "1.75rem", fontWeight: "700" }}>Bảng Xếp Hạng Học Sinh</h2>
        <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem" }}>
          Vinh danh các học sinh xuất sắc có điểm thành tích và tích cực nhất
        </p>
      </div>

      {/* Top 3 Podium */}
      {!loading && sortedStudents.length >= 3 && (
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
            gap: "1.25rem",
            marginBottom: "2rem",
            alignItems: "end",
          }}
        >
          {/* Top 2 - Silver */}
          {top2 && (
            <div
              className="glass-panel"
              style={{
                padding: "1.5rem",
                textAlign: "center",
                border: "2px solid #94a3b8",
                position: "relative",
              }}
            >
              <div
                style={{
                  width: "50px",
                  height: "50px",
                  borderRadius: "50%",
                  backgroundColor: "rgba(148, 163, 184, 0.2)",
                  color: "#94a3b8",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  margin: "0 auto 0.75rem auto",
                }}
              >
                <Medal size={28} />
              </div>
              <span style={{ fontSize: "0.75rem", fontWeight: "700", color: "#94a3b8" }}>HẠNG 2</span>
              <h4 style={{ fontSize: "1.2rem", fontWeight: "700", margin: "0.25rem 0" }}>{top2.ten}</h4>
              <p style={{ fontSize: "0.85rem", color: "var(--text-secondary)" }}>{top2.truong || "Học sinh"}</p>
              <div
                style={{
                  marginTop: "0.75rem",
                  fontSize: "1.25rem",
                  fontWeight: "700",
                  color: "var(--accent-primary)",
                }}
              >
                {top2.calculatedScore} điểm
              </div>
            </div>
          )}

          {/* Top 1 - Gold */}
          {top1 && (
            <div
              className="glass-panel"
              style={{
                padding: "2rem 1.5rem",
                textAlign: "center",
                border: "2px solid #f59e0b",
                transform: "scale(1.05)",
                backgroundColor: "rgba(245, 158, 11, 0.08)",
                position: "relative",
              }}
            >
              <div
                style={{
                  width: "60px",
                  height: "60px",
                  borderRadius: "50%",
                  backgroundColor: "rgba(245, 158, 11, 0.2)",
                  color: "#f59e0b",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  margin: "0 auto 0.75rem auto",
                  boxShadow: "0 0 20px rgba(245, 158, 11, 0.4)",
                }}
              >
                <Crown size={36} />
              </div>
              <span style={{ fontSize: "0.8rem", fontWeight: "800", color: "#f59e0b", letterSpacing: "1px" }}>
                QUÁN QUÂN HẠNG 1
              </span>
              <h3 style={{ fontSize: "1.4rem", fontWeight: "800", margin: "0.25rem 0" }}>{top1.ten}</h3>
              <p style={{ fontSize: "0.85rem", color: "var(--text-secondary)" }}>{top1.truong || "Học sinh"}</p>
              <div
                style={{
                  marginTop: "0.75rem",
                  fontSize: "1.5rem",
                  fontWeight: "800",
                  color: "#f59e0b",
                }}
              >
                {top1.calculatedScore} điểm
              </div>
            </div>
          )}

          {/* Top 3 - Bronze */}
          {top3 && (
            <div
              className="glass-panel"
              style={{
                padding: "1.5rem",
                textAlign: "center",
                border: "2px solid #b45309",
                position: "relative",
              }}
            >
              <div
                style={{
                  width: "50px",
                  height: "50px",
                  borderRadius: "50%",
                  backgroundColor: "rgba(180, 83, 9, 0.2)",
                  color: "#b45309",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  margin: "0 auto 0.75rem auto",
                }}
              >
                <Award size={28} />
              </div>
              <span style={{ fontSize: "0.75rem", fontWeight: "700", color: "#b45309" }}>HẠNG 3</span>
              <h4 style={{ fontSize: "1.2rem", fontWeight: "700", margin: "0.25rem 0" }}>{top3.ten}</h4>
              <p style={{ fontSize: "0.85rem", color: "var(--text-secondary)" }}>{top3.truong || "Học sinh"}</p>
              <div
                style={{
                  marginTop: "0.75rem",
                  fontSize: "1.25rem",
                  fontWeight: "700",
                  color: "var(--accent-primary)",
                }}
              >
                {top3.calculatedScore} điểm
              </div>
            </div>
          )}
        </div>
      )}

      {/* Complete Leaderboard Table */}
      <div className="glass-panel" style={{ overflow: "hidden" }}>
        <div style={{ padding: "1.25rem 1.5rem", borderBottom: "1px solid var(--border-color)" }}>
          <h3 style={{ fontSize: "1.1rem", fontWeight: "700", display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <Trophy size={20} color="var(--accent-primary)" />
            Bảng Xếp Hạng Đầy Đủ
          </h3>
        </div>

        {loading ? (
          <div style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
            Đang tính toán bảng xếp hạng...
          </div>
        ) : sortedStudents.length === 0 ? (
          <div style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
            Chưa có dữ liệu học sinh.
          </div>
        ) : (
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th style={{ width: "80px", textAlign: "center" }}>Hạng</th>
                  <th>Họ & Tên Học Sinh</th>
                  <th>Trường Học</th>
                  <th>SĐT Phụ Huynh</th>
                  <th style={{ textAlign: "right" }}>Tổng Điểm Thưởng</th>
                </tr>
              </thead>
              <tbody>
                {sortedStudents.map((s, idx) => (
                  <tr key={s._key}>
                    <td style={{ textAlign: "center", fontWeight: "700" }}>
                      {idx === 0 ? (
                        <span style={{ color: "#f59e0b", fontSize: "1.1rem" }}>🥇 1</span>
                      ) : idx === 1 ? (
                        <span style={{ color: "#94a3b8", fontSize: "1.1rem" }}>🥈 2</span>
                      ) : idx === 2 ? (
                        <span style={{ color: "#b45309", fontSize: "1.1rem" }}>🥉 3</span>
                      ) : (
                        `#${idx + 1}`
                      )}
                    </td>
                    <td style={{ fontWeight: "600" }}>{s.ten}</td>
                    <td>{s.truong || "--"}</td>
                    <td>{s.sdt_phu_huynh || s.sdt || "--"}</td>
                    <td style={{ textAlign: "right", fontWeight: "700", color: "var(--accent-primary)" }}>
                      <div style={{ display: "inline-flex", alignItems: "center", gap: "0.35rem" }}>
                        <Star size={16} color="#f59e0b" fill="#f59e0b" />
                        {s.calculatedScore} pts
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
