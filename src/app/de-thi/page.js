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
  AlertCircle,
  Edit3,
  ListCheck,
  Type
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
  const [quizAnswers, setQuizAnswers] = useState({}); // { 0: 'A', 1: {0: 'DUNG', 1: 'SAI'}, 2: '10' }
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
        loai_cau_hoi: "TRAC_NGHIEM_4_DAP_AN",
        noi_dung: "Câu 1 (4 Lựa Chọn): Cho hàm số y = 2x + 3. Giá trị của hàm số tại x = 2 là:",
        phuong_an: ["A) 5", "B) 7", "C) 8", "D) 6"],
        dap_an_dung: "B",
        giai_thich: "Thay x = 2 vào hàm số: y = 2*(2) + 3 = 7. Chọn B.",
      },
      {
        loai_cau_hoi: "TRAC_NGHIEM_DUNG_SAI",
        noi_dung: "Câu 2 (Đúng / Sai): Cho phương trình bậc hai x² - 5x + 6 = 0. Xét tính đúng/sai của các phát biểu sau:",
        y_hoi: [
          "a) Phương trình có hai nghiệm phân biệt",
          "b) Tổng hai nghiệm x₁ + x₂ = 5",
          "c) Tích hai nghiệm x₁ * x₂ = -6",
          "d) Hai nghiệm của phương trình là x₁ = 2 và x₂ = 3",
        ],
        dap_an_dung: { 0: "DUNG", 1: "DUNG", 2: "SAI", 3: "DUNG" },
        giai_thich: "Δ = 25 - 24 = 1 > 0 nên có 2 nghiệm. Theo Vi-et: x1+x2=5 (Đúng), x1*x2=6 (Chứ không phải -6 -> Sai). Nghiệm là 2 và 3 (Đúng).",
      },
      {
        loai_cau_hoi: "TRA_LOI_NGAN",
        noi_dung: "Câu 3 (Trả Lời Ngắn): Tính giá trị của biểu thức A = √(25) + 3*√(4). Điền kết quả dạng số:",
        dap_an_dung: "11",
        giai_thich: "A = 5 + 3*2 = 5 + 6 = 11. Kết quả điền số là 11.",
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
          handleFinishQuiz();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(timer);
  }, [quizStarted, quizResult, quizTimeLeft]);

  // Seed sample initial exams with 3 Question Types
  const seedInitialExams = async () => {
    const defaultExams = [
      {
        id: "de_toan9_dinh_cao",
        tieu_de: "Đề Kiểm Tra Tổng Hợp Môn Toán Khối 9 (Gồm 3 Dạng Câu Hỏi)",
        mon: "TOAN",
        khoi: "9",
        loai: "KIEM_TRA",
        thoi_gian_phut: 45,
        lop_id: "ALL",
        mo_ta: "Đề kiểm tra cấu trúc mới của Bộ GD&ĐT gồm: Trắc nghiệm 4 lựa chọn, Trắc nghiệm Đúng/Sai và Trả lời ngắn.",
        created_at: new Date().toLocaleDateString("vi-VN"),
        cau_hoi: [
          {
            loai_cau_hoi: "TRAC_NGHIEM_4_DAP_AN",
            noi_dung: "Câu 1: Giá trị của √(16) + √(9) bằng bao nhiêu?",
            phuong_an: ["A) 5", "B) 7", "C) 12", "D) 25"],
            dap_an_dung: "B",
            giai_thich: "√(16) = 4, √(9) = 3 -> 4 + 3 = 7. Đáp án B.",
          },
          {
            loai_cau_hoi: "TRAC_NGHIEM_DUNG_SAI",
            noi_dung: "Câu 2: Cho tam giác ABC vuông tại A có AB = 6cm, AC = 8cm. Xét tính đúng/sai của các mệnh đề:",
            y_hoi: [
              "a) Cạnh huyền BC có độ dài là 10 cm",
              "b) Đường cao AH ứng với cạnh huyền có độ dài là 4.8 cm",
              "c) Diện tích tam giác ABC bằng 48 cm²",
              "d) Bán kính đường tròn ngoại tiếp tam giác ABC là 5 cm",
            ],
            dap_an_dung: { 0: "DUNG", 1: "DUNG", 2: "SAI", 3: "DUNG" },
            giai_thich: "BC = √(6²+8²) = 10cm (Đúng). AH = 6*8/10 = 4.8cm (Đúng). S = ½*6*8 = 24cm² (chứ không phải 48cm² -> Sai). R = BC/2 = 5cm (Đúng).",
          },
          {
            loai_cau_hoi: "TRA_LOI_NGAN",
            noi_dung: "Câu 3: Tìm giá trị của x để căn thức √(2x - 10) bằng 0. Điền kết quả số:",
            dap_an_dung: "5",
            giai_thich: "√(2x - 10) = 0 <=> 2x - 10 = 0 <=> 2x = 10 <=> x = 5. Kết quả điền số là 5.",
          },
        ],
      },
      {
        id: "de_khtn8_3dang",
        tieu_de: "Bài Tập Về Nhà KHTN 8 - Biến Đổi Hóa Học & Phản Ứng Tỏa Nhiệt",
        mon: "KHTN",
        khoi: "8",
        loai: "BTVN",
        thoi_gian_phut: 30,
        lop_id: "ALL",
        mo_ta: "BTVN rèn luyện phản ứng hóa học KHTN 8 bám sát 3 dạng trắc nghiệm.",
        created_at: new Date().toLocaleDateString("vi-VN"),
        cau_hoi: [
          {
            loai_cau_hoi: "TRAC_NGHIEM_4_DAP_AN",
            noi_dung: "Câu 1: Hiện tượng nào sau đây thể hiện một phản ứng hóa học?",
            phuong_an: ["A) Nước đá tan thành nước lỏng", "B) Cơm bị ôi thiu", "C) Hòa tan đường vào nước", "D) Đốt nến chảy nến"],
            dap_an_dung: "B",
            giai_thich: "Cơm ôi thiu tạo ra chất mới có mùi hôi biến đổi cấu trúc chất. Chọn B.",
          },
          {
            loai_cau_hoi: "TRAC_NGHIEM_DUNG_SAI",
            noi_dung: "Câu 2: Cho phản ứng: 3Fe + 2O₂ -> Fe₃O₄ (t°). Đánh giá tính đúng/sai:",
            y_hoi: [
              "a) Phản ứng trên thuộc loại phản ứng hóa hợp",
              "b) Chất tham gia phản ứng gồm sắt (Fe) và khí ôxi (O₂)",
              "c) Để tạo ra 1 mol Fe₃O₄ cần dùng 2 mol Fe",
              "d) Đây là phản ứng tỏa nhiệt",
            ],
            dap_an_dung: { 0: "DUNG", 1: "DUNG", 2: "SAI", 3: "DUNG" },
            giai_thich: "Hóa hợp từ 2 chất thành 1 chất (Đúng). Cần 3 mol Fe chứ không phải 2 mol (Ý c Sai). Đốt sắt tỏa nhiệt mạnh (Đúng).",
          },
          {
            loai_cau_hoi: "TRA_LOI_NGAN",
            noi_dung: "Câu 3: Khối lượng mol phân tử của nước H₂O là bao nhiêu g/mol? (Biết H=1, O=16). Điền số:",
            dap_an_dung: "18",
            giai_thich: "M(H₂O) = 1*2 + 16 = 18 g/mol. Kết quả số là 18.",
          },
        ],
      },
      {
        id: "de_vatli10_3dang",
        tieu_de: "Đề Kiểm Tra 45p Vật Lý 10 - Chuyển Động Thẳng Biến Đổi Đều",
        mon: "VAT_LI",
        khoi: "10",
        loai: "KIEM_TRA",
        thoi_gian_phut: 45,
        lop_id: "ALL",
        mo_ta: "Kiểm tra kiến thức Chuyển động thẳng đều, gia tốc và quãng đường đi được môn Vật Lý 10.",
        created_at: new Date().toLocaleDateString("vi-VN"),
        cau_hoi: [
          {
            loai_cau_hoi: "TRAC_NGHIEM_4_DAP_AN",
            noi_dung: "Câu 1: Công thức tính vận tốc trong chuyển động thẳng biến đổi đều là:",
            phuong_an: ["A) v = v₀ + at", "B) v = v₀ + ½at²", "C) v = at", "D) v = v₀ - at²"],
            dap_an_dung: "A",
            giai_thich: "Vận tốc tức thời v = v₀ + at. Chọn A.",
          },
          {
            loai_cau_hoi: "TRAC_NGHIEM_DUNG_SAI",
            noi_dung: "Câu 2: Một ô tô bắt đầu tăng tốc nhanh dần đều từ trạng thái nghỉ với gia tốc a = 2 m/s². Xét các mệnh đề:",
            y_hoi: [
              "a) Vận tốc ban đầu v₀ = 0 m/s",
              "b) Sau 5 giây vận tốc của xe đạt 10 m/s",
              "c) Quãng đường xe đi được sau 5 giây đầu tiên là 25 mét",
              "d) Gia tốc của xe giảm dần theo thời gian",
            ],
            dap_an_dung: { 0: "DUNG", 1: "DUNG", 2: "DUNG", 3: "SAI" },
            giai_thich: "v₀ = 0 (Đúng). v = 2*5 = 10 m/s (Đúng). s = ½*2*5² = 25m (Đúng). Gia tốc a = 2 m/s² không đổi theo thời gian (Ý d Sai).",
          },
          {
            loai_cau_hoi: "TRA_LOI_NGAN",
            noi_dung: "Câu 3: Một xe đạp đang di chuyển với vận tốc 4 m/s thì hãm phanh chậm dần đều và dừng lại sau 2 giây. Gia tốc hãm phanh có độ lớn bằng bao nhiêu m/s²? Điền số:",
            dap_an_dung: "2",
            giai_thich: "v = v₀ + at => 0 = 4 + a*2 => a = -2 m/s². Độ lớn gia tốc hãm phanh là 2 m/s².",
          },
        ],
      },
    ];

    for (const ex of defaultExams) {
      await set(ref(db, `de_thi/${ex.id}`), ex);
    }
  };

  // Format Badges
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

  // Filtered Exams List
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

  // --- TEACHER: ADD QUESTION TO NEW EXAM FORM ---
  const handleAddQuestionToNewExam = (questionType = "TRAC_NGHIEM_4_DAP_AN") => {
    let newQ = {
      loai_cau_hoi: questionType,
      noi_dung: `Câu ${newExam.cau_hoi.length + 1}: `,
      giai_thich: "",
    };

    if (questionType === "TRAC_NGHIEM_4_DAP_AN") {
      newQ.phuong_an = ["A) ", "B) ", "C) ", "D) "];
      newQ.dap_an_dung = "A";
    } else if (questionType === "TRAC_NGHIEM_DUNG_SAI") {
      newQ.y_hoi = ["a) Ý hỏi 1", "b) Ý hỏi 2", "c) Ý hỏi 3", "d) Ý hỏi 4"];
      newQ.dap_an_dung = { 0: "DUNG", 1: "SAI", 2: "DUNG", 3: "DUNG" };
    } else if (questionType === "TRA_LOI_NGAN") {
      newQ.dap_an_dung = "10";
    }

    setNewExam((prev) => ({
      ...prev,
      cau_hoi: [...prev.cau_hoi, newQ],
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

  // --- STUDENT: SUBMIT QUIZ & CALCULATE SCORE FOR ALL 3 TYPES ---
  const handleFinishQuiz = async () => {
    if (!activeQuizExam) return;

    const questions = activeQuizExam.cau_hoi || [];
    let totalScorePoints = 0;
    const qWeight = 10 / questions.length; // Max score 10.0

    questions.forEach((q, idx) => {
      const type = q.loai_cau_hoi || "TRAC_NGHIEM_4_DAP_AN";
      const studentAns = quizAnswers[idx];

      if (type === "TRAC_NGHIEM_4_DAP_AN") {
        if (studentAns === q.dap_an_dung) {
          totalScorePoints += qWeight;
        }
      } else if (type === "TRAC_NGHIEM_DUNG_SAI") {
        const subItems = q.y_hoi || [];
        const correctAnswersObj = q.dap_an_dung || {};
        const studentAnswersObj = studentAns || {};

        let correctSubCount = 0;
        subItems.forEach((_, sIdx) => {
          if (studentAnswersObj[sIdx] && studentAnswersObj[sIdx] === correctAnswersObj[sIdx]) {
            correctSubCount++;
          }
        });

        // Grading rule for True/False (4 sub items)
        if (correctSubCount === 4) totalScorePoints += qWeight;
        else if (correctSubCount === 3) totalScorePoints += qWeight * 0.5;
        else if (correctSubCount === 2) totalScorePoints += qWeight * 0.25;
        else if (correctSubCount === 1) totalScorePoints += qWeight * 0.1;

      } else if (type === "TRA_LOI_NGAN") {
        const expAns = String(q.dap_an_dung || "").trim().toLowerCase();
        const stdAns = String(studentAns || "").trim().toLowerCase();
        if (stdAns && stdAns === expAns) {
          totalScorePoints += qWeight;
        }
      }
    });

    const finalScore = Math.round(totalScorePoints * 10) / 10;
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
      diem_so: finalScore,
      answers: quizAnswers,
      ngay_nop: timestamp,
    };

    setQuizResult({
      score: finalScore,
      totalCount: questions.length,
      submissionData,
    });

    try {
      // 1. Save submission to firebase
      await set(ref(db, `ket_qua_bai_thi/${submissionData.id}`), submissionData);

      // 2. Automatically sync score for monthly student evaluation
      const monthKey = new Date().toISOString().slice(0, 7);
      await set(ref(db, `danh_gia_hoc_tap/${monthKey}/${quizStudentId}/${activeQuizExam.id}`), {
        ten_bai_thi: activeQuizExam.tieu_de,
        diem_so: finalScore,
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
    return `${mins < 10 ? "0" + mins : mins}:${secs < 10 ? "0" + secs : secs}`;
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
            Cấu trúc 3 dạng câu hỏi chuẩn Bộ GD&ĐT: <strong>Trắc nghiệm 4 đáp án</strong>, <strong>Đúng/Sai (Nhiều ý)</strong> & <strong>Trả lời ngắn (Gõ bàn phím)</strong>!
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
                      <HelpCircle size={14} color="var(--accent-primary)" /> {qCount} câu (3 Dạng)
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

      {/* MODAL 1: STUDENT QUIZ TAKING MODAL (SUPPORTS ALL 3 QUESTION TYPES) */}
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
              maxWidth: "800px",
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

            {/* STEP 1: SELECT STUDENT */}
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
                    <div style={{ fontSize: "0.82rem", color: "var(--text-secondary)", lineHeight: "1.5" }}>
                      Đề thi bao gồm 3 dạng bài tập chuẩn Bộ GD&ĐT:
                      <br />- <strong>Dạng 1:</strong> Trắc nghiệm 4 lựa chọn (A/B/C/D).
                      <br />- <strong>Dạng 2:</strong> Trắc nghiệm Đúng / Sai (chọn ĐÚNG hoặc SAI cho từng ý a, b, c, d).
                      <br />- <strong>Dạng 3:</strong> Câu hỏi trả lời ngắn (Điền đáp án từ bàn phím).
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

            {/* STEP 2: ACTIVE QUIZ PLAYER (ALL 3 QUESTION TYPES) */}
            {quizStarted && !quizResult && (() => {
              const questions = activeQuizExam.cau_hoi || [];
              const curQ = questions[quizCurrentIndex];
              const qType = curQ.loai_cau_hoi || "TRAC_NGHIEM_4_DAP_AN";

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

                  {/* Question Navigator Pills */}
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

                  {/* QUESTION CONTAINER BY TYPE */}
                  {curQ && (
                    <div style={{ backgroundColor: "var(--bg-primary)", padding: "1.25rem", borderRadius: "14px", border: "1px solid var(--border-color)", marginBottom: "1.5rem" }}>
                      <div style={{ marginBottom: "0.6rem" }}>
                        {qType === "TRAC_NGHIEM_4_DAP_AN" && (
                          <span style={{ fontSize: "0.75rem", backgroundColor: "rgba(13, 148, 136, 0.2)", color: "var(--accent-primary)", padding: "0.2rem 0.5rem", borderRadius: "6px", fontWeight: "700" }}>
                            DẠNG 1: TRẮC NGHIỆM 4 LỰA CHỌN (1 ĐÁP ÁN ĐÚNG)
                          </span>
                        )}
                        {qType === "TRAC_NGHIEM_DUNG_SAI" && (
                          <span style={{ fontSize: "0.75rem", backgroundColor: "rgba(245, 158, 11, 0.2)", color: "var(--warning)", padding: "0.2rem 0.5rem", borderRadius: "6px", fontWeight: "700" }}>
                            DẠNG 2: TRẮC NGHIỆM ĐÚNG / SAI (4 Ý HỎI)
                          </span>
                        )}
                        {qType === "TRA_LOI_NGAN" && (
                          <span style={{ fontSize: "0.75rem", backgroundColor: "rgba(59, 130, 246, 0.2)", color: "var(--info)", padding: "0.2rem 0.5rem", borderRadius: "6px", fontWeight: "700" }}>
                            DẠNG 3: CÂU HỎI TRẢ LỜI NGẮN (ĐIỀN BÀN PHÍM)
                          </span>
                        )}
                      </div>

                      <h4 style={{ fontSize: "1.05rem", fontWeight: "700", marginBottom: "1.25rem", lineHeight: "1.5" }}>
                        {curQ.noi_dung}
                      </h4>

                      {/* TYPE 1: 4 OPTION SINGLE CHOICE */}
                      {qType === "TRAC_NGHIEM_4_DAP_AN" && (
                        <div style={{ display: "flex", flexDirection: "column", gap: "0.75rem" }}>
                          {(curQ.phuong_an || []).map((opt, oIdx) => {
                            const optionLetter = opt.charAt(0);
                            const isSelected = quizAnswers[quizCurrentIndex] === optionLetter;

                            return (
                              <button
                                key={oIdx}
                                type="button"
                                onClick={() =>
                                  setQuizAnswers((prev) => ({
                                    ...prev,
                                    [quizCurrentIndex]: optionLetter,
                                  }))
                                }
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
                                }}
                              >
                                {opt}
                              </button>
                            );
                          })}
                        </div>
                      )}

                      {/* TYPE 2: TRUE / FALSE SUB-ITEMS */}
                      {qType === "TRAC_NGHIEM_DUNG_SAI" && (
                        <div style={{ display: "flex", flexDirection: "column", gap: "0.85rem" }}>
                          {(curQ.y_hoi || []).map((subItem, sIdx) => {
                            const currentSubAns = (quizAnswers[quizCurrentIndex] || {})[sIdx];

                            return (
                              <div
                                key={sIdx}
                                style={{
                                  display: "flex",
                                  justifyContent: "space-between",
                                  alignItems: "center",
                                  backgroundColor: "var(--bg-secondary)",
                                  padding: "0.85rem 1rem",
                                  borderRadius: "12px",
                                  border: "1px solid var(--border-color)",
                                  flexWrap: "wrap",
                                  gap: "0.5rem",
                                }}
                              >
                                <span style={{ fontSize: "0.92rem", fontWeight: "600", flex: 1 }}>{subItem}</span>

                                <div style={{ display: "flex", gap: "0.5rem" }}>
                                  <button
                                    type="button"
                                    onClick={() =>
                                      setQuizAnswers((prev) => ({
                                        ...prev,
                                        [quizCurrentIndex]: {
                                          ...(prev[quizCurrentIndex] || {}),
                                          [sIdx]: "DUNG",
                                        },
                                      }))
                                    }
                                    style={{
                                      padding: "0.4rem 0.9rem",
                                      borderRadius: "8px",
                                      border: currentSubAns === "DUNG" ? "2px solid var(--success)" : "1px solid var(--border-color)",
                                      backgroundColor: currentSubAns === "DUNG" ? "rgba(16, 185, 129, 0.2)" : "var(--bg-primary)",
                                      color: currentSubAns === "DUNG" ? "var(--success)" : "var(--text-secondary)",
                                      fontWeight: "700",
                                      fontSize: "0.85rem",
                                      cursor: "pointer",
                                    }}
                                  >
                                    ✓ ĐÚNG
                                  </button>

                                  <button
                                    type="button"
                                    onClick={() =>
                                      setQuizAnswers((prev) => ({
                                        ...prev,
                                        [quizCurrentIndex]: {
                                          ...(prev[quizCurrentIndex] || {}),
                                          [sIdx]: "SAI",
                                        },
                                      }))
                                    }
                                    style={{
                                      padding: "0.4rem 0.9rem",
                                      borderRadius: "8px",
                                      border: currentSubAns === "SAI" ? "2px solid var(--danger)" : "1px solid var(--border-color)",
                                      backgroundColor: currentSubAns === "SAI" ? "rgba(239, 68, 68, 0.2)" : "var(--bg-primary)",
                                      color: currentSubAns === "SAI" ? "var(--danger)" : "var(--text-secondary)",
                                      fontWeight: "700",
                                      fontSize: "0.85rem",
                                      cursor: "pointer",
                                    }}
                                  >
                                    ✗ SAI
                                  </button>
                                </div>
                              </div>
                            );
                          })}
                        </div>
                      )}

                      {/* TYPE 3: SHORT ANSWER KEYBOARD INPUT */}
                      {qType === "TRA_LOI_NGAN" && (
                        <div>
                          <label style={{ display: "block", fontSize: "0.88rem", fontWeight: "700", marginBottom: "0.5rem", color: "var(--info)" }}>
                            ✍️ Nhập câu trả lời của bạn từ bàn phím:
                          </label>
                          <input
                            type="text"
                            placeholder="Gõ kết quả số hoặc đáp án vào đây..."
                            value={quizAnswers[quizCurrentIndex] || ""}
                            onChange={(e) =>
                              setQuizAnswers((prev) => ({
                                ...prev,
                                [quizCurrentIndex]: e.target.value,
                              }))
                            }
                            style={{
                              width: "100%",
                              padding: "0.85rem 1rem",
                              borderRadius: "12px",
                              backgroundColor: "var(--bg-secondary)",
                              border: "2px solid var(--info)",
                              color: "var(--text-primary)",
                              fontWeight: "700",
                              fontSize: "1.1rem",
                              outline: "none",
                            }}
                          />
                        </div>
                      )}
                    </div>
                  )}

                  {/* Navigation & Submit Controls */}
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

            {/* STEP 3: RESULTS & SOLUTIONS FOR ALL 3 TYPES */}
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
                    Điểm số bài thi 3 dạng đã được tự động lưu vào hồ sơ đánh giá học tập tháng!
                  </p>
                </div>

                {/* Solutions Breakdown */}
                <h4 style={{ fontSize: "1.05rem", fontWeight: "700", marginBottom: "1rem" }}>
                  Chi Tiết Đáp Án & Lời Giải Hướng Dẫn:
                </h4>

                <div style={{ display: "flex", flexDirection: "column", gap: "1rem", marginBottom: "1.5rem" }}>
                  {(activeQuizExam.cau_hoi || []).map((q, idx) => {
                    const type = q.loai_cau_hoi || "TRAC_NGHIEM_4_DAP_AN";
                    const studentAns = quizAnswers[idx];

                    return (
                      <div
                        key={idx}
                        style={{
                          backgroundColor: "var(--bg-primary)",
                          padding: "1.1rem",
                          borderRadius: "14px",
                          border: "1px solid var(--border-color)",
                        }}
                      >
                        <div style={{ fontWeight: "700", fontSize: "0.95rem", marginBottom: "0.5rem" }}>
                          {q.noi_dung}
                        </div>

                        {type === "TRAC_NGHIEM_4_DAP_AN" && (
                          <div style={{ fontSize: "0.88rem", color: "var(--text-secondary)", marginBottom: "0.5rem" }}>
                            Bạn chọn: <strong style={{ color: studentAns === q.dap_an_dung ? "var(--success)" : "var(--danger)" }}>{studentAns || "Chưa chọn"}</strong> | Đáp án đúng: <strong style={{ color: "var(--success)" }}>{q.dap_an_dung}</strong>
                          </div>
                        )}

                        {type === "TRAC_NGHIEM_DUNG_SAI" && (
                          <div style={{ display: "flex", flexDirection: "column", gap: "0.35rem", marginBottom: "0.5rem", fontSize: "0.85rem" }}>
                            {(q.y_hoi || []).map((y, sIdx) => {
                              const stdSub = (studentAns || {})[sIdx];
                              const expSub = (q.dap_an_dung || {})[sIdx];
                              const isMatch = stdSub === expSub;

                              return (
                                <div key={sIdx} style={{ color: isMatch ? "var(--success)" : "var(--danger)" }}>
                                  - {y}: Bạn chọn <strong>{stdSub || "Chưa chọn"}</strong> (Đáp án đúng: <strong>{expSub}</strong>) {isMatch ? "✓" : "✗"}
                                </div>
                              );
                            })}
                          </div>
                        )}

                        {type === "TRA_LOI_NGAN" && (
                          <div style={{ fontSize: "0.88rem", color: "var(--text-secondary)", marginBottom: "0.5rem" }}>
                            Bạn gõ: <strong style={{ color: String(studentAns || "").trim().toLowerCase() === String(q.dap_an_dung || "").trim().toLowerCase() ? "var(--success)" : "var(--danger)" }}>{studentAns || "Chưa nhập"}</strong> | Đáp án đúng: <strong style={{ color: "var(--success)" }}>{q.dap_an_dung}</strong>
                          </div>
                        )}

                        {q.giai_thich && (
                          <div style={{ backgroundColor: "rgba(13, 148, 136, 0.1)", padding: "0.65rem 0.85rem", borderRadius: "8px", fontSize: "0.85rem", color: "var(--accent-primary)", marginTop: "0.5rem" }}>
                            💡 <strong>Lời giải chi tiết:</strong> {q.giai_thich}
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

      {/* MODAL 2: TEACHER RESULTS VIEW MODAL */}
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
                        <th>Điểm Số</th>
                        <th>Ngày Nộp</th>
                      </tr>
                    </thead>
                    <tbody>
                      {examSubs.map((sub, i) => (
                        <tr key={sub.id || i}>
                          <td>{i + 1}</td>
                          <td><strong>{sub.ten_hoc_sinh}</strong></td>
                          <td>
                            <span style={{ fontWeight: "800", color: sub.diem_so >= 8 ? "var(--success)" : sub.diem_so >= 5 ? "var(--warning)" : "var(--danger)" }}>
                              {sub.diem_so} / 10.0
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

      {/* MODAL 3: TEACHER CREATE EXAM MODAL (SUPPORTS BUILDING 3 QUESTION TYPES) */}
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
              maxWidth: "900px",
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
                Tạo Đề Thi / Bài Tập Về Nhà Mới (3 Dạng Bài Tập)
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
                    placeholder="Ví dụ: Đề thi tổng hợp 3 dạng Môn Toán Khối 9 - Chương 1"
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
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem", flexWrap: "wrap", gap: "0.5rem" }}>
                  <h4 style={{ fontSize: "1.1rem", fontWeight: "700" }}>
                    Danh Sách Câu Hỏi ({newExam.cau_hoi.length} câu)
                  </h4>

                  <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}>
                    <button
                      type="button"
                      onClick={() => handleAddQuestionToNewExam("TRAC_NGHIEM_4_DAP_AN")}
                      className="btn-secondary"
                      style={{ padding: "0.45rem 0.85rem", fontSize: "0.82rem", fontWeight: "600" }}
                    >
                      ➕ Thêm Câu Trắc Nghiệm 4 Đáp Án
                    </button>

                    <button
                      type="button"
                      onClick={() => handleAddQuestionToNewExam("TRAC_NGHIEM_DUNG_SAI")}
                      className="btn-secondary"
                      style={{ padding: "0.45rem 0.85rem", fontSize: "0.82rem", fontWeight: "600", color: "var(--warning)" }}
                    >
                      ➕ Thêm Câu Đúng/Sai
                    </button>

                    <button
                      type="button"
                      onClick={() => handleAddQuestionToNewExam("TRA_LOI_NGAN")}
                      className="btn-secondary"
                      style={{ padding: "0.45rem 0.85rem", fontSize: "0.82rem", fontWeight: "600", color: "var(--info)" }}
                    >
                      ➕ Thêm Câu Trả Lời Ngắn
                    </button>
                  </div>
                </div>

                <div style={{ display: "flex", flexDirection: "column", gap: "1.25rem" }}>
                  {newExam.cau_hoi.map((q, qIdx) => {
                    const qType = q.loai_cau_hoi || "TRAC_NGHIEM_4_DAP_AN";

                    return (
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
                          <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                            <span style={{ fontWeight: "700", color: "var(--accent-primary)" }}>Câu {qIdx + 1}</span>
                            <select
                              value={qType}
                              onChange={(e) => {
                                const newType = e.target.value;
                                setNewExam((prev) => {
                                  const updated = [...prev.cau_hoi];
                                  updated[qIdx].loai_cau_hoi = newType;
                                  if (newType === "TRAC_NGHIEM_4_DAP_AN" && !updated[qIdx].phuong_an) {
                                    updated[qIdx].phuong_an = ["A) ", "B) ", "C) ", "D) "];
                                    updated[qIdx].dap_an_dung = "A";
                                  } else if (newType === "TRAC_NGHIEM_DUNG_SAI" && !updated[qIdx].y_hoi) {
                                    updated[qIdx].y_hoi = ["a) ", "b) ", "c) ", "d) "];
                                    updated[qIdx].dap_an_dung = { 0: "DUNG", 1: "SAI", 2: "DUNG", 3: "DUNG" };
                                  } else if (newType === "TRA_LOI_NGAN" && typeof updated[qIdx].dap_an_dung !== "string") {
                                    updated[qIdx].dap_an_dung = "10";
                                  }
                                  return { ...prev, cau_hoi: updated };
                                });
                              }}
                              style={{
                                padding: "0.25rem 0.5rem",
                                borderRadius: "6px",
                                backgroundColor: "var(--bg-secondary)",
                                border: "1px solid var(--border-color)",
                                color: "var(--text-primary)",
                                fontSize: "0.8rem",
                                fontWeight: "600",
                              }}
                            >
                              <option value="TRAC_NGHIEM_4_DAP_AN">Trắc nghiệm 4 đáp án (1 lựa chọn đúng)</option>
                              <option value="TRAC_NGHIEM_DUNG_SAI">Trắc nghiệm Đúng / Sai (nhiều ý a,b,c,d)</option>
                              <option value="TRA_LOI_NGAN">Trả lời ngắn (Gõ bàn phím)</option>
                            </select>
                          </div>

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

                        {/* Question Text Input */}
                        <textarea
                          rows={2}
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

                        {/* TYPE 1 BUILDER: 4 OPTIONS */}
                        {qType === "TRAC_NGHIEM_4_DAP_AN" && (
                          <div>
                            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0.5rem", marginBottom: "0.75rem" }}>
                              {(q.phuong_an || ["A) ", "B) ", "C) ", "D) "]).map((opt, oIdx) => (
                                <input
                                  key={oIdx}
                                  type="text"
                                  required
                                  value={opt}
                                  onChange={(e) => {
                                    const val = e.target.value;
                                    setNewExam((prev) => {
                                      const updated = [...prev.cau_hoi];
                                      if (!updated[qIdx].phuong_an) updated[qIdx].phuong_an = ["A) ", "B) ", "C) ", "D) "];
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

                            <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
                              <label style={{ fontSize: "0.85rem", fontWeight: "700" }}>Đáp Án Đúng:</label>
                              <select
                                value={q.dap_an_dung || "A"}
                                onChange={(e) => {
                                  const val = e.target.value;
                                  setNewExam((prev) => {
                                    const updated = [...prev.cau_hoi];
                                    updated[qIdx].dap_an_dung = val;
                                    return { ...prev, cau_hoi: updated };
                                  });
                                }}
                                style={{
                                  padding: "0.45rem 1rem",
                                  borderRadius: "8px",
                                  backgroundColor: "var(--bg-secondary)",
                                  border: "1px solid var(--border-color)",
                                  color: "var(--text-primary)",
                                  fontWeight: "700",
                                }}
                              >
                                <option value="A">Phương án A</option>
                                <option value="B">Phương án B</option>
                                <option value="C">Phương án C</option>
                                <option value="D">Phương án D</option>
                              </select>
                            </div>
                          </div>
                        )}

                        {/* TYPE 2 BUILDER: TRUE / FALSE SUB-ITEMS */}
                        {qType === "TRAC_NGHIEM_DUNG_SAI" && (
                          <div style={{ display: "flex", flexDirection: "column", gap: "0.6rem", marginBottom: "0.75rem" }}>
                            <label style={{ fontSize: "0.85rem", fontWeight: "700", color: "var(--warning)" }}>
                              Nhập 4 phát biểu và chọn đáp án ĐÚNG hoặc SAI cho từng ý:
                            </label>
                            {(q.y_hoi || ["a) ", "b) ", "c) ", "d) "]).map((yText, sIdx) => {
                              const curAns = (q.dap_an_dung || {})[sIdx] || "DUNG";

                              return (
                                <div key={sIdx} style={{ display: "flex", gap: "0.5rem", alignItems: "center" }}>
                                  <input
                                    type="text"
                                    required
                                    value={yText}
                                    onChange={(e) => {
                                      const val = e.target.value;
                                      setNewExam((prev) => {
                                        const updated = [...prev.cau_hoi];
                                        if (!updated[qIdx].y_hoi) updated[qIdx].y_hoi = ["a) ", "b) ", "c) ", "d) "];
                                        updated[qIdx].y_hoi[sIdx] = val;
                                        return { ...prev, cau_hoi: updated };
                                      });
                                    }}
                                    style={{
                                      flex: 1,
                                      padding: "0.55rem",
                                      borderRadius: "8px",
                                      backgroundColor: "var(--bg-secondary)",
                                      border: "1px solid var(--border-color)",
                                      color: "var(--text-primary)",
                                      outline: "none",
                                      fontSize: "0.88rem",
                                    }}
                                  />

                                  <select
                                    value={curAns}
                                    onChange={(e) => {
                                      const val = e.target.value;
                                      setNewExam((prev) => {
                                        const updated = [...prev.cau_hoi];
                                        const curObj = typeof updated[qIdx].dap_an_dung === "object" ? updated[qIdx].dap_an_dung : {};
                                        updated[qIdx].dap_an_dung = { ...curObj, [sIdx]: val };
                                        return { ...prev, cau_hoi: updated };
                                      });
                                    }}
                                    style={{
                                      padding: "0.55rem",
                                      borderRadius: "8px",
                                      backgroundColor: curAns === "DUNG" ? "rgba(16, 185, 129, 0.2)" : "rgba(239, 68, 68, 0.2)",
                                      color: curAns === "DUNG" ? "var(--success)" : "var(--danger)",
                                      border: "1px solid var(--border-color)",
                                      fontWeight: "700",
                                      fontSize: "0.85rem",
                                    }}
                                  >
                                    <option value="DUNG">✓ ĐÚNG</option>
                                    <option value="SAI">✗ SAI</option>
                                  </select>
                                </div>
                              );
                            })}
                          </div>
                        )}

                        {/* TYPE 3 BUILDER: SHORT ANSWER TEXT */}
                        {qType === "TRA_LOI_NGAN" && (
                          <div style={{ marginBottom: "0.75rem" }}>
                            <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.3rem", color: "var(--info)" }}>
                              Đáp án chuẩn cần học sinh gõ từ bàn phím:
                            </label>
                            <input
                              type="text"
                              required
                              placeholder="Ví dụ: 10 hoặc 2.5 hoặc Phản ứng tỏa nhiệt"
                              value={typeof q.dap_an_dung === "string" ? q.dap_an_dung : ""}
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
                                padding: "0.65rem",
                                borderRadius: "8px",
                                backgroundColor: "var(--bg-secondary)",
                                border: "1px solid var(--info)",
                                color: "var(--text-primary)",
                                fontWeight: "700",
                                outline: "none",
                              }}
                            />
                          </div>
                        )}

                        {/* Explanation Input */}
                        <div style={{ marginTop: "0.5rem" }}>
                          <label style={{ display: "block", fontSize: "0.8rem", fontWeight: "700", marginBottom: "0.2rem" }}>
                            Lời Giải Chi Tiết / Hướng Dẫn:
                          </label>
                          <input
                            type="text"
                            placeholder="Nhập hướng dẫn lời giải để học sinh xem sau khi nộp..."
                            value={q.giai_thich || ""}
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
                    );
                  })}
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
