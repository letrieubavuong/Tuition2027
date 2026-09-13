"use client";

import { useEffect, useState } from "react";
import { db, ref, onValue, set, push, remove } from "@/lib/firebase";
import {
  FileText,
  Plus,
  Search,
  BookOpen,
  CheckCircle2,
  XCircle,
  Clock,
  Award,
  Users,
  Brain,
  Sparkles,
  Send,
  Trash2,
  Eye,
  BarChart2,
  ChevronLeft,
  ChevronRight,
  HelpCircle,
  PlayCircle,
  RotateCcw,
  Check,
  AlertCircle
} from "lucide-react";

export default function DeThiPage() {
  const [exams, setExams] = useState([]);
  const [classes, setClasses] = useState([]);
  const [students, setStudents] = useState([]);
  const [submissions, setSubmissions] = useState([]);
  const [loading, setLoading] = useState(true);

  // Filter States
  const [selectedSubject, setSelectedSubject] = useState("ALL"); // ALL, TOAN, KHTN, VAT_LI
  const [selectedGrade, setSelectedGrade] = useState("ALL"); // ALL, 6..12
  const [selectedType, setSelectedType] = useState("ALL"); // ALL, BTVN, KIEM_TRA, THI_THU
  const [searchQuery, setSearchQuery] = useState("");

  // Modal Controls
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showResultsModal, setShowResultsModal] = useState(null); // exam object
  const [activeQuizExam, setActiveQuizExam] = useState(null); // exam student is taking

  // Quiz Taking State
  const [quizStudentId, setQuizStudentId] = useState("");
  const [quizClassId, setQuizClassId] = useState("");
  const [quizStarted, setQuizStarted] = useState(false);
  const [quizAnswers, setQuizAnswers] = useState({}); // { 0: 'A', 1: 'C' }
  const [quizCurrentIndex, setQuizCurrentIndex] = useState(0);
  const [quizTimeLeft, setQuizTimeLeft] = useState(0);
  const [quizResult, setQuizResult] = useState(null); // { score, correct, total, answers }

  // New Exam Form State
  const [newExam, setNewExam] = useState({
    tieu_de: "",
    mon: "TOAN", // TOAN, KHTN, VAT_LI
    khoi: "9", // 6 -> 12
    loai: "BTVN", // BTVN, KIEM_TRA, THI_THU
    thoi_gian_phut: 45,
    lop_id: "ALL",
    mo_ta: "",
    cau_hoi: [
      {
        noi_dung: "Câu 1: Cho hàm số y = 2x + 3. Giá trị của hàm số tại x = 2 là:",
        phuong_an: ["A) 5", "B) 7", "C) 8", "D) 6"],
        dap_an_dung: "B",
        giai_thich: "Thay x = 2 vào hàm số: y = 2*(2) + 3 = 7. Chọn B.",
      },
      {
        noi_dung: "Câu 2: Phương trình bậc hai ax² + bx + c = 0 (a ≠ 0) có Biệt thức Delta Δ là:",
        phuong_an: ["A) Δ = b² - 4ac", "B) Δ = b² + 4ac", "C) Δ = b - 4ac", "D) Δ = b² - ac"],
        dap_an_dung: "A",
        giai_thich: "Công thức tính biệt thức Delta chuẩn là Δ = b² - 4ac. Chọn A.",
      },
    ],
  });

  // Load Data from Firebase
  useEffect(() => {
    // 1. Load Classes
    const lopRef = ref(db, "lop");
    const unsubLop = onValue(lopRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        setClasses(list);
      }
    });

    // 2. Load Students
    const hsRef = ref(db, "hoc_sinh");
    const unsubHs = onValue(hsRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        setStudents(list);
      }
    });

    // 3. Load Submissions
    const subRef = ref(db, "ket_qua_bai_thi");
    const unsubSub = onValue(subRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        const list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        setSubmissions(list);
      } else {
        setSubmissions([]);
      }
    });

    // 4. Load Exams (with automatic seed if empty)
    const examRef = ref(db, "de_thi");
    const unsubExams = onValue(examRef, (snapshot) => {
      const val = snapshot.val();
      if (val) {
        let list = Array.isArray(val) ? val.filter(Boolean) : Object.values(val);
        setExams(list.reverse());
      } else {
        // Seed default standard exams for Toán, KHTN, Vật Lí
        seedInitialExams();
      }
      setLoading(false);
    });

    return () => {
      unsubLop();
      unsubHs();
      unsubSub();
      unsubExams();
    };
  }, []);

  // Timer countdown hook for student quiz taking
  useEffect(() => {
    if (!quizStarted || quizResult || quizTimeLeft <= 0) return;
    const timer = setInterval(() => {
      setQuizTimeLeft((prev) => {
        if (prev <= 1) {
          clearInterval(timer);
          handleFinishQuiz(); // Auto submit when time runs out
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(timer);
  }, [quizStarted, quizResult, quizTimeLeft]);

  // Seed sample initial exams
  const seedInitialExams = async () => {
    const defaultExams = [
      {
        id: "de_toan9_ki1",
        tieu_de: "Đề Thi Ôn Tập Giữa Kỳ 1 - Môn Toán Khối 9",
        mon: "TOAN",
        khoi: "9",
        loai: "KIEM_TRA",
        thoi_gian_phut: 45,
        lop_id: "ALL",
        mo_ta: "Đề kiểm tra trắc nghiệm tổng hợp Căn bậc hai, Hàm số bậc nhất và Hệ phương thức lượng trong tam giác vuông.",
        created_at: new Date().toLocaleDateString("vi-VN"),
        cau_hoi: [
          {
            noi_dung: "Câu 1: Giá trị của √(16) + √(9) bằng bao nhiêu?",
            phuong_an: ["A) 5", "B) 7", "C) 12", "D) 25"],
            dap_an_dung: "B",
            giai_thich: "√(16) = 4, √(9) = 3 -> 4 + 3 = 7. Đáp án B.",
          },
          {
            noi_dung: "Câu 2: Hàm số y = (m - 2)x + 5 đồng biến trên R khi và chỉ khi:",
            phuong_an: ["A) m > 2", "B) m < 2", "C) m = 2", "D) m ≥ 2"],
            dap_an_dung: "A",
            giai_thich: "Hàm số bậc nhất y = ax + b đồng biến khi a > 0 <=> m - 2 > 0 <=> m > 2. Đáp án A.",
          },
          {
            noi_dung: "Câu 3: Cho tam giác ABC vuông tại A có AB = 6cm, AC = 8cm. Đường cao AH có độ dài là:",
            phuong_an: ["A) 4.8 cm", "B) 5 cm", "C) 10 cm", "D) 6.4 cm"],
            dap_an_dung: "A",
            giai_thich: "BC = √(6² + 8²) = 10cm. Áp dụng hệ thức lượng AB*AC = BC*AH => AH = (6*8)/10 = 4.8cm. Đáp án A.",
          },
          {
            noi_dung: "Câu 4: Căn thức √(2x - 6) có nghĩa (xác định) khi:",
            phuong_an: ["A) x ≥ 3", "B) x ≤ 3", "C) x > 3", "D) x ≠ 3"],
            dap_an_dung: "A",
            giai_thich: "Căn thức có nghĩa khi 2x - 6 ≥ 0 <=> 2x ≥ 6 <=> x ≥ 3. Đáp án A.",
          },
        ],
      },
      {
        id: "de_khtn8_btvn",
        tieu_de: "Bài Tập Về Nhà KHTN 8 - Chuyện Đổi Hóa Học & Phản Ứng",
        mon: "KHTN",
        khoi: "8",
        loai: "BTVN",
        thoi_gian_phut: 30,
        lop_id: "ALL",
        mo_ta: "Bài tập về nhà rèn luyện kỹ năng phân biệt biến đổi hóa học & cân bằng phương trình hóa học cơ bản KHTN 8.",
        created_at: new Date().toLocaleDateString("vi-VN"),
        cau_hoi: [
          {
            noi_dung: "Câu 1: Hiện tượng nào sau đây là hiện tượng hóa học?",
            phuong_an: ["A) Nước đá tan thành nước lỏng", "B) Cơm bị ôi thiu", "C) Hòa tan đường vào nước", "D) Hòa tan muối vào nước"],
            dap_an_dung: "B",
            giai_thich: "Cơm ôi thiu sinh ra chất mới có mùi hôi biến đổi cấu trúc hóa học. Chọn B.",
          },
          {
            noi_dung: "Câu 2: Phản ứng tỏa nhiệt là phản ứng hóa học trong đó:",
            phuong_an: ["A) Giải phóng năng lượng dưới dạng nhiệt", "B) Hấp thụ năng lượng dưới dạng nhiệt", "C) Không thay đổi nhiệt độ", "D) Luôn giảm nhiệt độ môi trường"],
            dap_an_dung: "A",
            giai_thich: "Phản ứng tỏa nhiệt là phản ứng giải phóng nhiệt năng ra môi trường xung quanh. Chọn A.",
          },
          {
            noi_dung: "Câu 3: Điền hệ số thích hợp để cân bằng: Fe + O₂ -> Fe₃O₄",
            phuong_an: ["A) 3Fe + 2O₂ -> Fe₃O₄", "B) Fe + O₂ -> Fe₃O₄", "C) 2Fe + 3O₂ -> Fe₃O₄", "D) 3Fe + O₂ -> Fe₃O₄"],
            dap_an_dung: "A",
            giai_thich: "Bên phải có 3Fe và 4O. Thêm hệ số 3 vào Fe và 2 vào O₂ -> 3Fe + 2O₂ -> Fe₃O₄. Chọn A.",
          },
        ],
      },
      {
        id: "de_vatli10_chuyen_dong",
        tieu_de: "Đề Kiểm Tra 45p Vật Lý 10 - Chuyển Động Thẳng Biến Đổi Đều",
        mon: "VAT_LI",
        khoi: "10",
        loai: "KIEM_TRA",
        thoi_gian_phut: 45,
        lop_id: "ALL",
        mo_ta: "Đề thi đánh giá năng lực Vật Lý 10 bài Chuyển động thẳng đều, biến đổi đều và Công thức gia tốc.",
        created_at: new Date().toLocaleDateString("vi-VN"),
        cau_hoi: [
          {
            noi_dung: "Câu 1: Công thức tính vận tốc của chuyển động thẳng biến đổi đều là:",
            phuong_an: ["A) v = v₀ + at", "B) v = v₀ + ½at²", "C) v = at", "D) v = v₀ - at²"],
            dap_an_dung: "A",
            giai_thich: "Vận tốc tức thời v trong chuyển động thẳng biến đổi đều: v = v₀ + at. Chọn A.",
          },
          {
            noi_dung: "Câu 2: Một xe máy bắt đầu khởi động nhanh dần đều với gia tốc a = 2 m/s². Sau 5s vận tốc đạt được là:",
            phuong_an: ["A) 10 m/s", "B) 5 m/s", "C) 20 m/s", "D) 15 m/s"],
            dap_an_dung: "A",
            giai_thich: "v₀ = 0, a = 2, t = 5 => v = 0 + 2*5 = 10 m/s. Chọn A.",
          },
          {
            noi_dung: "Câu 3: Đồ thị vận tốc - thời gian (v - t) của chuyển động thẳng đều là một đường:",
            phuong_an: ["A) Song song với trục thời gian t", "B) Đi qua gốc tọa độ", "C) Đồ thị hình Parabol", "D) Đường cong bất kỳ"],
            dap_an_dung: "A",
            giai_thich: "Chuyển động thẳng đều có v = không đổi theo thời gian nên đồ thị v-t là đường thẳng song song với trục Ot. Chọn A.",
          },
        ],
      },
    ];

    for (const ex of defaultExams) {
      await set(ref(db, `de_thi/${ex.id}`), ex);
    }
  };

  // Format Helpers
  const getSubjectBadge = (mon) => {
    switch (mon) {
      case "TOAN":
        return { label: "📐 TOÁN 6-12", bg: "rgba(13, 148, 136, 0.15)", color: "var(--accent-primary)" };
      case "KHTN":
        return { label: "🔬 KHTN 6-9", bg: "rgba(16, 185, 129, 0.15)", color: "var(--success)" };
      case "VAT_LI":
        return { label: "⚡ VẬT LÍ 10-12", bg: "rgba(59, 130, 246, 0.15)", color: "var(--info)" };
      default:
        return { label: mon, bg: "rgba(245, 158, 11, 0.15)", color: "var(--warning)" };
    }
  };

  const getTypeBadge = (loai) => {
    switch (loai) {
      case "BTVN":
        return { label: "📝 BTVN Về Nhà", bg: "rgba(59, 130, 246, 0.15)", color: "var(--info)" };
      case "KIEM_TRA":
        return { label: "⏱️ Đề Kiểm Tra Lấy Điểm", bg: "rgba(239, 68, 68, 0.15)", color: "var(--danger)" };
      case "THI_THU":
        return { label: "🎯 Đề Thi Thử", bg: "rgba(245, 158, 11, 0.15)", color: "var(--warning)" };
      default:
        return { label: loai, bg: "var(--bg-secondary)", color: "var(--text-secondary)" };
    }
  };

  // Filtered Exams
  const filteredExams = exams.filter((ex) => {
    if (!ex) return false;
    const matchesSubject = selectedSubject === "ALL" || ex.mon === selectedSubject;
    const matchesGrade = selectedGrade === "ALL" || String(ex.khoi) === String(selectedGrade);
    const matchesType = selectedType === "ALL" || ex.loai === selectedType;
    const matchesSearch =
      !searchQuery ||
      (ex.tieu_de && ex.tieu_de.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (ex.mo_ta && ex.mo_ta.toLowerCase().includes(searchQuery.toLowerCase()));

    return matchesSubject && matchesGrade && matchesType && matchesSearch;
  });

  // --- TEACHER: ADD NEW QUESTION TO EXAM FORM ---
  const handleAddQuestionToNewExam = () => {
    setNewExam((prev) => ({
      ...prev,
      cau_hoi: [
        ...prev.cau_hoi,
        {
          noi_dung: `Câu ${prev.cau_hoi.length + 1}: `,
          phuong_an: ["A) ", "B) ", "C) ", "D) "],
          dap_an_dung: "A",
          giai_thich: "",
        },
      ],
    }));
  };

  const handleRemoveQuestion = (idx) => {
    setNewExam((prev) => ({
      ...prev,
      cau_hoi: prev.cau_hoi.filter((_, i) => i !== idx),
    }));
  };

  // --- TEACHER: SAVE NEW EXAM TO FIREBASE ---
  const handleSaveNewExam = async (e) => {
    e.preventDefault();
    if (!newExam.tieu_de || newExam.cau_hoi.length === 0) {
      alert("Vui lòng nhập Tiêu đề và tạo ít nhất 1 câu hỏi!");
      return;
    }

    try {
      const examId = `de_${newExam.mon.toLowerCase()}_k${newExam.khoi}_${Date.now()}`;
      const examData = {
        id: examId,
        ...newExam,
        created_at: new Date().toLocaleDateString("vi-VN"),
      };

      await set(ref(db, `de_thi/${examId}`), examData);
      alert("Đã tải lên và phát hành đề thi / BTVN mới thành công!");
      setShowCreateModal(false);
      setNewExam({
        tieu_de: "",
        mon: "TOAN",
        khoi: "9",
        loai: "BTVN",
        thoi_gian_phut: 45,
        lop_id: "ALL",
        mo_ta: "",
        cau_hoi: [
          {
            noi_dung: "Câu 1: ",
            phuong_an: ["A) ", "B) ", "C) ", "D) "],
            dap_an_dung: "A",
            giai_thich: "",
          },
        ],
      });
    } catch (err) {
      alert("Lỗi khi lưu đề thi: " + err.message);
    }
  };

  const handleDeleteExam = async (examId) => {
    if (!confirm("Bạn có chắc chắn muốn xóa bài thi này khỏi hệ thống?")) return;
    try {
      await remove(ref(db, `de_thi/${examId}`));
      alert("Đã xóa đề thi!");
    } catch (err) {
      alert("Lỗi khi xóa: " + err.message);
    }
  };

  // --- STUDENT: START QUIZ ---
  const handleOpenStartQuizModal = (exam) => {
    setActiveQuizExam(exam);
    setQuizStudentId("");
    setQuizClassId("");
    setQuizStarted(false);
    setQuizAnswers({});
    setQuizCurrentIndex(0);
    setQuizResult(null);
    setQuizTimeLeft((exam.thoi_gian_phut || 45) * 60);
  };

  const handleStartQuizNow = () => {
    if (!quizStudentId) {
      alert("Vui lòng chọn Tên học sinh của bạn để tiến hành làm bài!");
      return;
    }
    setQuizStarted(true);
  };

  const handleSelectAnswer = (qIndex, optionLetter) => {
    setQuizAnswers((prev) => ({
      ...prev,
      [qIndex]: optionLetter,
    }));
  };

  // --- STUDENT: SUBMIT QUIZ & AUTO GRADE ---
  const handleFinishQuiz = async () => {
    if (!activeQuizExam) return;

    const questions = activeQuizExam.cau_hoi || [];
    let correctCount = 0;

    questions.forEach((q, idx) => {
      const studentAns = quizAnswers[idx];
      const correctAns = q.dap_an_dung;
      if (studentAns === correctAns) {
        correctCount++;
      }
    });

    const score = Math.round((correctCount / questions.length) * 10 * 10) / 10;
    const selectedStudent = students.find((s) => String(s.id || s._key) === String(quizStudentId));
    const studentName = selectedStudent ? selectedStudent.ten : `Học sinh #${quizStudentId}`;
    const timestamp = new Date().toLocaleString("vi-VN");

    const submissionData = {
      id: `sub_${quizStudentId}_${activeQuizExam.id}_${Date.now()}`,
      exam_id: activeQuizExam.id,
      exam_title: activeQuizExam.tieu_de,
      mon: activeQuizExam.mon,
      khoi: activeQuizExam.khoi,
      hoc_sinh_id: quizStudentId,
      ten_hoc_sinh: studentName,
      lop_id: quizClassId,
      diem_so: score,
      so_cau_dung: correctCount,
      tong_so_cau: questions.length,
      answers: quizAnswers,
      ngay_nop: timestamp,
    };

    setQuizResult({
      score,
      correctCount,
      totalCount: questions.length,
      submissionData,
    });

    try {
      // 1. Save submission to firebase
      await set(ref(db, `ket_qua_bai_thi/${submissionData.id}`), submissionData);

      // 2. Automatically sync score to student evaluation for monthly grading
      const monthKey = new Date().toISOString().slice(0, 7); // e.g. 2026-09
      await set(ref(db, `danh_gia_hoc_tap/${monthKey}/${quizStudentId}/${activeQuizExam.id}`), {
        ten_bai_thi: activeQuizExam.tieu_de,
        diem_so: score,
        mon: activeQuizExam.mon,
        ngay_lam: timestamp,
      });
    } catch (err) {
      console.error("Lỗi khi lưu kết quả bài thi:", err);
    }
  };

  const formatTimer = (totalSeconds) => {
    const mins = Math.floor(totalSeconds / 60);
    const secs = totalSeconds % 60;
    return `${mins.toString().padLeft ? mins.toString().padStart(2, "0") : mins}:${secs.toString().padLeft ? secs.toString().padStart(2, "0") : secs}`;
  };

  return (
    <div>
      {/* Page Header */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "1rem", marginBottom: "1.5rem" }}>
        <div>
          <h2 style={{ fontSize: "1.75rem", fontWeight: "800", display: "flex", alignItems: "center", gap: "0.6rem" }}>
            <FileText size={28} color="var(--accent-primary)" />
            Quản Lý & Làm Bài Đề Thi - BTVN
          </h2>
          <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem", marginTop: "0.25rem" }}>
            Hệ thống Đề thi & Bài tập về nhà các môn <strong>TOÁN (Khối 6-12)</strong>, <strong>KHTN (Khối 6-9)</strong>, <strong>VẬT LÍ (Khối 10-12)</strong> - Cơ sở đánh giá học tập cuối tháng!
          </p>
        </div>

        <button
          type="button"
          onClick={() => setShowCreateModal(true)}
          className="btn-primary"
          style={{ display: "flex", alignItems: "center", gap: "0.5rem", padding: "0.75rem 1.25rem", fontWeight: "700" }}
        >
          <Plus size={18} />
          ➕ Tạo Đề Thi / BTVN Mới
        </button>
      </div>

      {/* FILTER BAR FOR SUBJECTS, GRADES & TYPES */}
      <div className="glass-panel" style={{ padding: "1.25rem", marginBottom: "1.5rem" }}>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: "1rem", alignItems: "center" }}>
          {/* Search Box */}
          <div style={{ position: "relative" }}>
            <Search size={16} color="var(--text-muted)" style={{ position: "absolute", left: "0.75rem", top: "50%", transform: "translateY(-50%)" }} />
            <input
              type="text"
              placeholder="Tìm tên đề thi, nội dung..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{
                width: "100%",
                padding: "0.65rem 0.65rem 0.65rem 2.25rem",
                borderRadius: "var(--radius-md)",
                backgroundColor: "var(--bg-secondary)",
                border: "1px solid var(--border-color)",
                color: "var(--text-primary)",
                outline: "none",
                fontSize: "0.9rem",
              }}
            />
          </div>

          {/* Subject Filter */}
          <div>
            <select
              value={selectedSubject}
              onChange={(e) => setSelectedSubject(e.target.value)}
              style={{
                width: "100%",
                padding: "0.65rem",
                borderRadius: "var(--radius-md)",
                backgroundColor: "var(--bg-secondary)",
                border: "1px solid var(--border-color)",
                color: "var(--text-primary)",
                outline: "none",
                fontWeight: "600",
              }}
            >
              <option value="ALL">📚 Tất cả môn học</option>
              <option value="TOAN">📐 Môn TOÁN (Khối 6 - 12)</option>
              <option value="KHTN">🔬 Môn KHTN (Khối 6 - 9)</option>
              <option value="VAT_LI">⚡ Môn VẬT LÍ (Khối 10 - 12)</option>
            </select>
          </div>

          {/* Grade Filter */}
          <div>
            <select
              value={selectedGrade}
              onChange={(e) => setSelectedGrade(e.target.value)}
              style={{
                width: "100%",
                padding: "0.65rem",
                borderRadius: "var(--radius-md)",
                backgroundColor: "var(--bg-secondary)",
                border: "1px solid var(--border-color)",
                color: "var(--text-primary)",
                outline: "none",
                fontWeight: "600",
              }}
            >
              <option value="ALL">🎓 Tất cả các Khối</option>
              <option value="6">Khối 6</option>
              <option value="7">Khối 7</option>
              <option value="8">Khối 8</option>
              <option value="9">Khối 9 (Luyện thi vào 10)</option>
              <option value="10">Khối 10</option>
              <option value="11">Khối 11</option>
              <option value="12">Khối 12 (Luyện thi THPT)</option>
            </select>
          </div>

          {/* Type Filter */}
          <div>
            <select
              value={selectedType}
              onChange={(e) => setSelectedType(e.target.value)}
              style={{
                width: "100%",
                padding: "0.65rem",
                borderRadius: "var(--radius-md)",
                backgroundColor: "var(--bg-secondary)",
                border: "1px solid var(--border-color)",
                color: "var(--text-primary)",
                outline: "none",
                fontWeight: "600",
              }}
            >
              <option value="ALL">📝 Tất cả loại hình</option>
              <option value="BTVN">📝 Bài Tập Về Nhà (BTVN)</option>
              <option value="KIEM_TRA">⏱️ Đề Kiểm Tra Lấy Điểm</option>
              <option value="THI_THU">🎯 Đề Thi Thử Tổng Hợp</option>
            </select>
          </div>
        </div>
      </div>

      {/* EXAMS LIST GRID */}
      {loading ? (
        <div style={{ padding: "4rem", textAlign: "center", color: "var(--text-muted)" }}>
          Đang nạp danh sách Đề thi & BTVN từ Cloud Firebase...
        </div>
      ) : filteredExams.length === 0 ? (
        <div className="glass-panel" style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
          <Brain size={40} style={{ marginBottom: "0.75rem", opacity: 0.5 }} />
          <p style={{ fontSize: "1rem", fontWeight: "600" }}>Chưa tìm thấy Đề thi / BTVN phù hợp với bộ lọc hiện tại.</p>
          <p style={{ fontSize: "0.85rem", marginTop: "0.25rem" }}>Nhấn nút "➕ Tạo Đề Thi / BTVN Mới" ở góc trên để phát hành bài làm cho học sinh.</p>
        </div>
      ) : (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(320px, 1fr))", gap: "1.25rem" }}>
          {filteredExams.map((ex) => {
            const subjBadge = getSubjectBadge(ex.mon);
            const typeBadge = getTypeBadge(ex.loai);
            const qCount = (ex.cau_hoi || []).length;
            const exSubs = submissions.filter((s) => s.exam_id === ex.id);

            return (
              <div
                key={ex.id}
                className="glass-panel"
                style={{
                  padding: "1.25rem",
                  display: "flex",
                  flexDirection: "column",
                  justifyContent: "space-between",
                  borderRadius: "16px",
                  border: "1px solid var(--border-color)",
                  transition: "transform 0.2s ease, box-shadow 0.2s ease",
                }}
              >
                <div>
                  {/* Badges Bar */}
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0.75rem", flexWrap: "wrap", gap: "0.4rem" }}>
                    <span
                      style={{
                        backgroundColor: subjBadge.bg,
                        color: subjBadge.color,
                        padding: "0.25rem 0.65rem",
                        borderRadius: "10px",
                        fontSize: "0.75rem",
                        fontWeight: "700",
                      }}
                    >
                      {subjBadge.label} (Khối {ex.khoi})
                    </span>

                    <span
                      style={{
                        backgroundColor: typeBadge.bg,
                        color: typeBadge.color,
                        padding: "0.25rem 0.65rem",
                        borderRadius: "10px",
                        fontSize: "0.75rem",
                        fontWeight: "700",
                      }}
                    >
                      {typeBadge.label}
                    </span>
                  </div>

                  {/* Title */}
                  <h3 style={{ fontSize: "1.1rem", fontWeight: "700", marginBottom: "0.5rem", lineHeight: "1.4" }}>
                    {ex.tieu_de}
                  </h3>

                  {/* Description */}
                  {ex.mo_ta && (
                    <p style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginBottom: "1rem", lineHeight: "1.5" }}>
                      {ex.mo_ta}
                    </p>
                  )}

                  {/* Meta Stats */}
                  <div style={{ display: "flex", gap: "1rem", fontSize: "0.82rem", color: "var(--text-muted)", marginBottom: "1.25rem", flexWrap: "wrap" }}>
                    <span style={{ display: "flex", alignItems: "center", gap: "0.3rem" }}>
                      <HelpCircle size={14} color="var(--accent-primary)" /> {qCount} câu hỏi
                    </span>
                    <span style={{ display: "flex", alignItems: "center", gap: "0.3rem" }}>
                      <Clock size={14} color="var(--warning)" /> {ex.thoi_gian_phut ? `${ex.thoi_gian_phut} phút` : "Không giới hạn"}
                    </span>
                    <span style={{ display: "flex", alignItems: "center", gap: "0.3rem" }}>
                      <Users size={14} color="var(--success)" /> {exSubs.length} lượt nộp
                    </span>
                  </div>
                </div>

                {/* Actions Footer */}
                <div style={{ display: "flex", gap: "0.5rem", borderTop: "1px solid var(--border-color)", paddingTop: "1rem", flexWrap: "wrap" }}>
                  <button
                    type="button"
                    onClick={() => handleOpenStartQuizModal(ex)}
                    className="btn-primary"
                    style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", gap: "0.4rem", padding: "0.6rem 0.85rem", fontSize: "0.88rem", fontWeight: "700" }}
                  >
                    <PlayCircle size={16} /> Làm Bài Ngay
                  </button>

                  <button
                    type="button"
                    onClick={() => setShowResultsModal(ex)}
                    className="btn-secondary"
                    style={{ padding: "0.6rem 0.85rem", color: "var(--accent-primary)", fontSize: "0.88rem" }}
                    title="Xem kết quả & điểm số của học sinh"
                  >
                    <BarChart2 size={16} /> Kết Quả ({exSubs.length})
                  </button>

                  <button
                    type="button"
                    onClick={() => handleDeleteExam(ex.id)}
                    className="btn-secondary"
                    style={{ padding: "0.6rem 0.65rem", color: "var(--danger)" }}
                    title="Xóa đề thi này"
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* MODAL 1: STUDENT QUIZ TAKING MODAL */}
      {activeQuizExam && (
        <div
          style={{
            position: "fixed",
            inset: 0,
            backgroundColor: "rgba(0, 0, 0, 0.75)",
            backdropFilter: "blur(6px)",
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
              maxWidth: "750px",
              maxHeight: "90vh",
              overflowY: "auto",
              padding: "1.75rem",
              backgroundColor: "var(--bg-secondary)",
              borderRadius: "20px",
            }}
          >
            {/* Header */}
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.25rem", borderBottom: "1px solid var(--border-color)", paddingBottom: "1rem" }}>
              <div>
                <span className="badge badge-info" style={{ marginBottom: "0.3rem" }}>
                  {activeQuizExam.mon} - Khối {activeQuizExam.khoi} ({activeQuizExam.loai})
                </span>
                <h3 style={{ fontSize: "1.25rem", fontWeight: "800" }}>{activeQuizExam.tieu_de}</h3>
              </div>

              <button
                onClick={() => setActiveQuizExam(null)}
                style={{ background: "none", border: "none", color: "var(--text-muted)", cursor: "pointer", fontSize: "1.5rem" }}
              >
                ✕
              </button>
            </div>

            {/* STEP 1: SELECT STUDENT & CLASS BEFORE STARTING */}
            {!quizStarted && !quizResult && (
              <div style={{ padding: "1rem 0" }}>
                <h4 style={{ fontSize: "1rem", fontWeight: "700", marginBottom: "0.75rem" }}>
                  Vui lòng chọn thông tin Học sinh để bắt đầu làm bài:
                </h4>

                <div style={{ display: "flex", flexDirection: "column", gap: "1rem", marginBottom: "1.5rem" }}>
                  <div>
                    <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                      Chọn Học Sinh *
                    </label>
                    <select
                      value={quizStudentId}
                      onChange={(e) => setQuizStudentId(e.target.value)}
                      style={{
                        width: "100%",
                        padding: "0.75rem",
                        borderRadius: "var(--radius-md)",
                        backgroundColor: "var(--bg-primary)",
                        border: "1px solid var(--border-color)",
                        color: "var(--text-primary)",
                        outline: "none",
                        fontWeight: "600",
                      }}
                    >
                      <option value="">-- Chọn tên học sinh từ danh sách trung tâm --</option>
                      {students.map((s) => (
                        <option key={s.id || s._key} value={s.id || s._key}>
                          {s.ten} {s.sdt_phu_huynh ? `(SĐT Phụ huynh: ${s.sdt_phu_huynh})` : ""}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div style={{ backgroundColor: "rgba(13, 148, 136, 0.1)", padding: "1rem", borderRadius: "12px", border: "1px solid var(--accent-primary)" }}>
                    <div style={{ fontSize: "0.88rem", fontWeight: "700", color: "var(--accent-primary)", marginBottom: "0.3rem" }}>
                      ⏱️ Thời gian làm bài: {activeQuizExam.thoi_gian_phut ? `${activeQuizExam.thoi_gian_phut} phút` : "Không giới hạn"}
                    </div>
                    <div style={{ fontSize: "0.82rem", color: "var(--text-secondary)" }}>
                      Bài thi có {(activeQuizExam.cau_hoi || []).length} câu hỏi trắc nghiệm. Kết quả và lời giải chi tiết sẽ hiển thị ngay sau khi bấm Nộp bài.
                    </div>
                  </div>
                </div>

                <div style={{ display: "flex", justifyContent: "flex-end" }}>
                  <button
                    type="button"
                    onClick={handleStartQuizNow}
                    className="btn-primary"
                    style={{ padding: "0.85rem 2rem", fontWeight: "700", fontSize: "1rem", display: "flex", alignItems: "center", gap: "0.5rem" }}
                  >
                    <PlayCircle size={20} /> Bắt Đầu Làm Bài
                  </button>
                </div>
              </div>
            )}

            {/* STEP 2: ACTIVE QUIZ PLAYER */}
            {quizStarted && !quizResult && (() => {
              const questions = activeQuizExam.cau_hoi || [];
              const curQ = questions[quizCurrentIndex];

              return (
                <div>
                  {/* Timer & Progress Bar */}
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.25rem", backgroundColor: "var(--bg-primary)", padding: "0.75rem 1rem", borderRadius: "12px" }}>
                    <div style={{ fontSize: "0.88rem", fontWeight: "700" }}>
                      Câu hỏi {quizCurrentIndex + 1} / {questions.length}
                    </div>

                    <div style={{ display: "flex", alignItems: "center", gap: "0.4rem", color: "var(--danger)", fontWeight: "800", fontSize: "1.1rem" }}>
                      <Clock size={18} /> {formatTimer(quizTimeLeft)}
                    </div>
                  </div>

                  {/* Question Pills Navigator */}
                  <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap", marginBottom: "1.5rem" }}>
                    {questions.map((_, idx) => {
                      const isAnswered = quizAnswers[idx] !== undefined;
                      const isCurrent = idx === quizCurrentIndex;

                      return (
                        <button
                          key={idx}
                          type="button"
                          onClick={() => setQuizCurrentIndex(idx)}
                          style={{
                            width: "36px",
                            height: "36px",
                            borderRadius: "10px",
                            border: isCurrent ? "2px solid var(--accent-primary)" : "1px solid var(--border-color)",
                            backgroundColor: isCurrent ? "var(--accent-primary)" : isAnswered ? "rgba(16, 185, 129, 0.2)" : "var(--bg-primary)",
                            color: isCurrent ? "#ffffff" : isAnswered ? "var(--success)" : "var(--text-primary)",
                            fontWeight: "700",
                            fontSize: "0.85rem",
                            cursor: "pointer",
                          }}
                        >
                          {idx + 1}
                        </button>
                      );
                    })}
                  </div>

                  {/* Question Box */}
                  {curQ && (
                    <div style={{ backgroundColor: "var(--bg-primary)", padding: "1.25rem", borderRadius: "14px", border: "1px solid var(--border-color)", marginBottom: "1.5rem" }}>
                      <h4 style={{ fontSize: "1.05rem", fontWeight: "700", marginBottom: "1.25rem", lineHeight: "1.5" }}>
                        {curQ.noi_dung}
                      </h4>

                      <div style={{ display: "flex", flexDirection: "column", gap: "0.75rem" }}>
                        {(curQ.phuong_an || []).map((opt, oIdx) => {
                          const optionLetter = opt.charAt(0); // 'A', 'B', 'C', 'D'
                          const isSelected = quizAnswers[quizCurrentIndex] === optionLetter;

                          return (
                            <button
                              key={oIdx}
                              type="button"
                              onClick={() => handleSelectAnswer(quizCurrentIndex, optionLetter)}
                              style={{
                                textAlign: "left",
                                padding: "0.85rem 1.1rem",
                                borderRadius: "12px",
                                border: isSelected ? "2px solid var(--accent-primary)" : "1px solid var(--border-color)",
                                backgroundColor: isSelected ? "rgba(13, 148, 136, 0.15)" : "var(--bg-secondary)",
                                color: isSelected ? "var(--accent-primary)" : "var(--text-primary)",
                                fontWeight: isSelected ? "700" : "500",
                                fontSize: "0.95rem",
                                cursor: "pointer",
                                transition: "all 0.15s ease",
                              }}
                            >
                              {opt}
                            </button>
                          );
                        })}
                      </div>
                    </div>
                  )}

                  {/* Navigation & Submit Buttons */}
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                    <button
                      type="button"
                      disabled={quizCurrentIndex === 0}
                      onClick={() => setQuizCurrentIndex((prev) => Math.max(0, prev - 1))}
                      className="btn-secondary"
                      style={{ padding: "0.65rem 1.25rem" }}
                    >
                      <ChevronLeft size={18} /> Câu trước
                    </button>

                    {quizCurrentIndex < questions.length - 1 ? (
                      <button
                        type="button"
                        onClick={() => setQuizCurrentIndex((prev) => prev + 1)}
                        className="btn-primary"
                        style={{ padding: "0.65rem 1.25rem" }}
                      >
                        Câu tiếp theo <ChevronRight size={18} />
                      </button>
                    ) : (
                      <button
                        type="button"
                        onClick={handleFinishQuiz}
                        className="btn-primary"
                        style={{ padding: "0.75rem 1.75rem", backgroundColor: "var(--success)", border: "none", fontWeight: "800", fontSize: "1rem" }}
                      >
                        ✓ NỘP BÀI THI
                      </button>
                    )}
                  </div>
                </div>
              );
            })()}

            {/* STEP 3: QUIZ RESULT & SOLUTIONS SCREEN */}
            {quizResult && (
              <div style={{ padding: "1rem 0" }}>
                <div style={{ textAlign: "center", marginBottom: "1.75rem", backgroundColor: "var(--bg-primary)", padding: "1.5rem", borderRadius: "16px", border: "1px solid var(--border-color)" }}>
                  <Award size={48} color="var(--warning)" style={{ marginBottom: "0.5rem" }} />
                  <h3 style={{ fontSize: "1.4rem", fontWeight: "800", marginBottom: "0.3rem" }}>
                    Kết Quả Bài Làm Của Bạn
                  </h3>
                  <div style={{ fontSize: "2.5rem", fontWeight: "900", color: quizResult.score >= 8 ? "var(--success)" : quizResult.score >= 5 ? "var(--warning)" : "var(--danger)", margin: "0.5rem 0" }}>
                    {quizResult.score} / 10.0
                  </div>
                  <p style={{ fontSize: "0.95rem", color: "var(--text-secondary)" }}>
                    Đã trả lời đúng <strong>{quizResult.correctCount} / {quizResult.totalCount}</strong> câu hỏi. Kết quả đã được tự động lưu vào hồ sơ đánh giá học tập tháng!
                  </p>
                </div>

                {/* Question Solutions List */}
                <h4 style={{ fontSize: "1.05rem", fontWeight: "700", marginBottom: "1rem" }}>
                  Chi Tiết Đáp Án & Hướng Dẫn Giải:
                </h4>

                <div style={{ display: "flex", flexDirection: "column", gap: "1rem", marginBottom: "1.5rem" }}>
                  {(activeQuizExam.cau_hoi || []).map((q, idx) => {
                    const studentAns = quizAnswers[idx];
                    const isCorrect = studentAns === q.dap_an_dung;

                    return (
                      <div
                        key={idx}
                        style={{
                          backgroundColor: "var(--bg-primary)",
                          padding: "1.1rem",
                          borderRadius: "14px",
                          border: isCorrect ? "1px solid var(--success)" : "1px solid var(--danger)",
                        }}
                      >
                        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "0.5rem" }}>
                          <span style={{ fontWeight: "700", fontSize: "0.95rem" }}>{q.noi_dung}</span>
                          {isCorrect ? (
                            <span style={{ color: "var(--success)", fontWeight: "700", fontSize: "0.85rem" }}>✓ Đúng (+{(10 / (activeQuizExam.cau_hoi.length)).toFixed(1)}đ)</span>
                          ) : (
                            <span style={{ color: "var(--danger)", fontWeight: "700", fontSize: "0.85rem" }}>✗ Sai</span>
                          )}
                        </div>

                        <div style={{ fontSize: "0.88rem", color: "var(--text-secondary)", marginBottom: "0.5rem" }}>
                          Đáp án bạn chọn: <strong style={{ color: isCorrect ? "var(--success)" : "var(--danger)" }}>{studentAns || "Chưa chọn"}</strong> | Đáp án đúng: <strong style={{ color: "var(--success)" }}>{q.dap_an_dung}</strong>
                        </div>

                        {q.giai_thich && (
                          <div style={{ backgroundColor: "rgba(13, 148, 136, 0.1)", padding: "0.65rem 0.85rem", borderRadius: "8px", fontSize: "0.85rem", color: "var(--accent-primary)", marginTop: "0.5rem" }}>
                            💡 <strong>Lời giải:</strong> {q.giai_thich}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>

                <div style={{ display: "flex", justifyContent: "flex-end" }}>
                  <button
                    type="button"
                    onClick={() => setActiveQuizExam(null)}
                    className="btn-primary"
                    style={{ padding: "0.75rem 2rem", fontWeight: "700" }}
                  >
                    Đóng
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* MODAL 2: TEACHER RESULTS & SUBMISSIONS VIEW MODAL */}
      {showResultsModal && (
        <div
          style={{
            position: "fixed",
            inset: 0,
            backgroundColor: "rgba(0, 0, 0, 0.7)",
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
              maxWidth: "800px",
              maxHeight: "85vh",
              overflowY: "auto",
              padding: "1.75rem",
              backgroundColor: "var(--bg-secondary)",
              borderRadius: "20px",
            }}
          >
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.25rem", borderBottom: "1px solid var(--border-color)", paddingBottom: "1rem" }}>
              <div>
                <h3 style={{ fontSize: "1.2rem", fontWeight: "800" }}>Bảng Điểm Học Sinh - {showResultsModal.tieu_de}</h3>
                <p style={{ fontSize: "0.85rem", color: "var(--text-secondary)" }}>
                  Môn: {showResultsModal.mon} - Khối {showResultsModal.khoi} ({showResultsModal.loai})
                </p>
              </div>

              <button onClick={() => setShowResultsModal(null)} style={{ background: "none", border: "none", color: "var(--text-muted)", cursor: "pointer", fontSize: "1.5rem" }}>
                ✕
              </button>
            </div>

            {/* Submissions Table */}
            {(() => {
              const examSubs = submissions.filter((s) => s.exam_id === showResultsModal.id);

              if (examSubs.length === 0) {
                return (
                  <div style={{ padding: "3rem", textAlign: "center", color: "var(--text-muted)" }}>
                    Chưa có học sinh nào nộp bài thi này.
                  </div>
                );
              }

              const avgScore = (examSubs.reduce((sum, s) => sum + (s.diem_so || 0), 0) / examSubs.length).toFixed(1);

              return (
                <div>
                  <div style={{ display: "flex", gap: "1rem", marginBottom: "1.25rem" }}>
                    <div style={{ backgroundColor: "var(--bg-primary)", padding: "0.85rem 1.25rem", borderRadius: "12px", border: "1px solid var(--border-color)" }}>
                      <div style={{ fontSize: "0.8rem", color: "var(--text-muted)" }}>Lượt nộp bài</div>
                      <div style={{ fontSize: "1.25rem", fontWeight: "800" }}>{examSubs.length} Học sinh</div>
                    </div>

                    <div style={{ backgroundColor: "var(--bg-primary)", padding: "0.85rem 1.25rem", borderRadius: "12px", border: "1px solid var(--border-color)" }}>
                      <div style={{ fontSize: "0.8rem", color: "var(--text-muted)" }}>Điểm trung bình</div>
                      <div style={{ fontSize: "1.25rem", fontWeight: "800", color: "var(--accent-primary)" }}>{avgScore} / 10</div>
                    </div>
                  </div>

                  <table className="custom-table" style={{ width: "100%", fontSize: "0.88rem" }}>
                    <thead>
                      <tr>
                        <th>STT</th>
                        <th>Tên Học Sinh</th>
                        <th>Số Câu Đúng</th>
                        <th>Điểm Số</th>
                        <th>Ngày Nộp</th>
                      </tr>
                    </thead>
                    <tbody>
                      {examSubs.map((sub, i) => (
                        <tr key={sub.id || i}>
                          <td>{i + 1}</td>
                          <td><strong>{sub.ten_hoc_sinh}</strong></td>
                          <td>{sub.so_cau_dung} / {sub.tong_so_cau} câu</td>
                          <td>
                            <span style={{ fontWeight: "800", color: sub.diem_so >= 8 ? "var(--success)" : sub.diem_so >= 5 ? "var(--warning)" : "var(--danger)" }}>
                              {sub.diem_so} / 10
                            </span>
                          </td>
                          <td>{sub.ngay_nop}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              );
            })()}
          </div>
        </div>
      )}

      {/* MODAL 3: TEACHER CREATE EXAM MODAL */}
      {showCreateModal && (
        <div
          style={{
            position: "fixed",
            inset: 0,
            backgroundColor: "rgba(0, 0, 0, 0.75)",
            backdropFilter: "blur(6px)",
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
              maxWidth: "850px",
              maxHeight: "90vh",
              overflowY: "auto",
              padding: "1.75rem",
              backgroundColor: "var(--bg-secondary)",
              borderRadius: "20px",
            }}
          >
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.25rem", borderBottom: "1px solid var(--border-color)", paddingBottom: "1rem" }}>
              <h3 style={{ fontSize: "1.25rem", fontWeight: "800", display: "flex", alignItems: "center", gap: "0.5rem" }}>
                <Plus size={22} color="var(--accent-primary)" />
                Tạo Đề Thi / Bài Tập Về Nhà Mới
              </h3>

              <button onClick={() => setShowCreateModal(false)} style={{ background: "none", border: "none", color: "var(--text-muted)", cursor: "pointer", fontSize: "1.5rem" }}>
                ✕
              </button>
            </div>

            <form onSubmit={handleSaveNewExam} style={{ display: "flex", flexDirection: "column", gap: "1.25rem" }}>
              <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))", gap: "1rem" }}>
                <div style={{ gridColumn: "1 / -1" }}>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                    Tên Đề Thi / Bài Tập *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="Ví dụ: Đề kiểm tra 45 phút Môn Toán Khối 9 - Chương 1"
                    value={newExam.tieu_de}
                    onChange={(e) => setNewExam({ ...newExam, tieu_de: e.target.value })}
                    style={{
                      width: "100%",
                      padding: "0.75rem",
                      borderRadius: "var(--radius-md)",
                      backgroundColor: "var(--bg-primary)",
                      border: "1px solid var(--border-color)",
                      color: "var(--text-primary)",
                      outline: "none",
                      fontWeight: "600",
                    }}
                  />
                </div>

                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                    Môn Học *
                  </label>
                  <select
                    value={newExam.mon}
                    onChange={(e) => setNewExam({ ...newExam, mon: e.target.value })}
                    style={{
                      width: "100%",
                      padding: "0.75rem",
                      borderRadius: "var(--radius-md)",
                      backgroundColor: "var(--bg-primary)",
                      border: "1px solid var(--border-color)",
                      color: "var(--text-primary)",
                      outline: "none",
                    }}
                  >
                    <option value="TOAN">📐 Môn TOÁN (Khối 6-12)</option>
                    <option value="KHTN">🔬 Môn KHTN (Khối 6-9)</option>
                    <option value="VAT_LI">⚡ Môn VẬT LÍ (Khối 10-12)</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                    Khối *
                  </label>
                  <select
                    value={newExam.khoi}
                    onChange={(e) => setNewExam({ ...newExam, khoi: e.target.value })}
                    style={{
                      width: "100%",
                      padding: "0.75rem",
                      borderRadius: "var(--radius-md)",
                      backgroundColor: "var(--bg-primary)",
                      border: "1px solid var(--border-color)",
                      color: "var(--text-primary)",
                      outline: "none",
                    }}
                  >
                    <option value="6">Khối 6</option>
                    <option value="7">Khối 7</option>
                    <option value="8">Khối 8</option>
                    <option value="9">Khối 9</option>
                    <option value="10">Khối 10</option>
                    <option value="11">Khối 11</option>
                    <option value="12">Khối 12</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                    Loại Hình *
                  </label>
                  <select
                    value={newExam.loai}
                    onChange={(e) => setNewExam({ ...newExam, loai: e.target.value })}
                    style={{
                      width: "100%",
                      padding: "0.75rem",
                      borderRadius: "var(--radius-md)",
                      backgroundColor: "var(--bg-primary)",
                      border: "1px solid var(--border-color)",
                      color: "var(--text-primary)",
                      outline: "none",
                    }}
                  >
                    <option value="BTVN">📝 Bài Tập Về Nhà (BTVN)</option>
                    <option value="KIEM_TRA">⏱️ Đề Kiểm Tra Lấy Điểm</option>
                    <option value="THI_THU">🎯 Đề Thi Thử Ôn Tập</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                    Thời gian làm bài (Phút)
                  </label>
                  <input
                    type="number"
                    value={newExam.thoi_gian_phut}
                    onChange={(e) => setNewExam({ ...newExam, thoi_gian_phut: Number(e.target.value) })}
                    style={{
                      width: "100%",
                      padding: "0.75rem",
                      borderRadius: "var(--radius-md)",
                      backgroundColor: "var(--bg-primary)",
                      border: "1px solid var(--border-color)",
                      color: "var(--text-primary)",
                      outline: "none",
                    }}
                  />
                </div>
              </div>

              {/* QUESTIONS BUILDER SECTION */}
              <div style={{ marginTop: "1rem", borderTop: "1px solid var(--border-color)", paddingTop: "1rem" }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem" }}>
                  <h4 style={{ fontSize: "1.1rem", fontWeight: "700" }}>
                    Danh Sách Câu Hỏi Trắc Nghiệm ({newExam.cau_hoi.length} câu)
                  </h4>

                  <button
                    type="button"
                    onClick={handleAddQuestionToNewExam}
                    className="btn-secondary"
                    style={{ padding: "0.5rem 1rem", fontSize: "0.85rem", fontWeight: "600" }}
                  >
                    ➕ Thêm Câu Hỏi Mới
                  </button>
                </div>

                <div style={{ display: "flex", flexDirection: "column", gap: "1.25rem" }}>
                  {newExam.cau_hoi.map((q, qIdx) => (
                    <div
                      key={qIdx}
                      style={{
                        backgroundColor: "var(--bg-primary)",
                        padding: "1.1rem",
                        borderRadius: "14px",
                        border: "1px solid var(--border-color)",
                      }}
                    >
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0.6rem" }}>
                        <span style={{ fontWeight: "700", color: "var(--accent-primary)" }}>Câu {qIdx + 1}</span>
                        {newExam.cau_hoi.length > 1 && (
                          <button
                            type="button"
                            onClick={() => handleRemoveQuestion(qIdx)}
                            style={{ background: "none", border: "none", color: "var(--danger)", cursor: "pointer", fontSize: "0.85rem" }}
                          >
                            Xóa câu này
                          </button>
                        )}
                      </div>

                      {/* Question Text */}
                      <input
                        type="text"
                        required
                        placeholder="Nội dung câu hỏi..."
                        value={q.noi_dung}
                        onChange={(e) => {
                          const val = e.target.value;
                          setNewExam((prev) => {
                            const updated = [...prev.cau_hoi];
                            updated[qIdx].noi_dung = val;
                            return { ...prev, cau_hoi: updated };
                          });
                        }}
                        style={{
                          width: "100%",
                          padding: "0.65rem",
                          borderRadius: "8px",
                          backgroundColor: "var(--bg-secondary)",
                          border: "1px solid var(--border-color)",
                          color: "var(--text-primary)",
                          outline: "none",
                          marginBottom: "0.75rem",
                          fontWeight: "600",
                        }}
                      />

                      {/* 4 Options Inputs */}
                      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0.5rem", marginBottom: "0.75rem" }}>
                        {q.phuong_an.map((opt, oIdx) => (
                          <input
                            key={oIdx}
                            type="text"
                            required
                            value={opt}
                            onChange={(e) => {
                              const val = e.target.value;
                              setNewExam((prev) => {
                                const updated = [...prev.cau_hoi];
                                updated[qIdx].phuong_an[oIdx] = val;
                                return { ...prev, cau_hoi: updated };
                              });
                            }}
                            style={{
                              padding: "0.55rem",
                              borderRadius: "8px",
                              backgroundColor: "var(--bg-secondary)",
                              border: "1px solid var(--border-color)",
                              color: "var(--text-primary)",
                              outline: "none",
                              fontSize: "0.88rem",
                            }}
                          />
                        ))}
                      </div>

                      {/* Correct Answer & Explanation */}
                      <div style={{ display: "grid", gridTemplateColumns: "150px 1fr", gap: "0.75rem", alignItems: "center" }}>
                        <div>
                          <label style={{ display: "block", fontSize: "0.8rem", fontWeight: "700", marginBottom: "0.2rem" }}>
                            Đáp Án Đúng:
                          </label>
                          <select
                            value={q.dap_an_dung}
                            onChange={(e) => {
                              const val = e.target.value;
                              setNewExam((prev) => {
                                const updated = [...prev.cau_hoi];
                                updated[qIdx].dap_an_dung = val;
                                return { ...prev, cau_hoi: updated };
                              });
                            }}
                            style={{
                              width: "100%",
                              padding: "0.5rem",
                              borderRadius: "8px",
                              backgroundColor: "var(--bg-secondary)",
                              border: "1px solid var(--border-color)",
                              color: "var(--text-primary)",
                              outline: "none",
                              fontWeight: "700",
                            }}
                          >
                            <option value="A">Phương án A</option>
                            <option value="B">Phương án B</option>
                            <option value="C">Phương án C</option>
                            <option value="D">Phương án D</option>
                          </select>
                        </div>

                        <div>
                          <label style={{ display: "block", fontSize: "0.8rem", fontWeight: "700", marginBottom: "0.2rem" }}>
                            Lời Giải Chi Tiết / Hướng Dẫn:
                          </label>
                          <input
                            type="text"
                            placeholder="Nhập lời giải để học sinh xem sau khi nộp..."
                            value={q.giai_thich}
                            onChange={(e) => {
                              const val = e.target.value;
                              setNewExam((prev) => {
                                const updated = [...prev.cau_hoi];
                                updated[qIdx].giai_thich = val;
                                return { ...prev, cau_hoi: updated };
                              });
                            }}
                            style={{
                              width: "100%",
                              padding: "0.5rem",
                              borderRadius: "8px",
                              backgroundColor: "var(--bg-secondary)",
                              border: "1px solid var(--border-color)",
                              color: "var(--text-primary)",
                              outline: "none",
                              fontSize: "0.85rem",
                            }}
                          />
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Submit Buttons */}
              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "1rem" }}>
                <button type="button" onClick={() => setShowCreateModal(false)} className="btn-secondary">
                  Hủy Bỏ
                </button>
                <button type="submit" className="btn-primary" style={{ padding: "0.75rem 2rem", fontWeight: "700" }}>
                  PHÁT HÀNH ĐỀ THI / BTVN
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
