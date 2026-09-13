"use client";

import { useEffect, useState } from "react";
import { db, ref, onValue, set, push, remove } from "@/lib/firebase";
import MathText from "@/components/MathText";
import { parseExTest } from "@/utils/texParser";
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
  Type,
  Upload,
  FileCode,
  FileUp,
  Sigma
} from "lucide-react";

export default function DeThiPage() {
  const [exams, setExams] = useState([]);
  const [classes, setClasses] = useState([]);
  const [students, setStudents] = useState([]);
  const [submissions, setSubmissions] = useState([]);
  const [loading, setLoading] = useState(true);

  // Filter States
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedSubject, setSelectedSubject] = useState("ALL"); // ALL, TOAN, KHTN, VAT_LI
  const [selectedGrade, setSelectedGrade] = useState("ALL"); // ALL, 6..12
  const [selectedType, setSelectedType] = useState("ALL"); // ALL, BTVN, KIEM_TRA, THI_THU

  // Modal States
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [activeQuizExam, setActiveQuizExam] = useState(null); // Exam object student is taking
  const [showResultsModal, setShowResultsModal] = useState(null); // Exam results for teacher
  const [showTexModal, setShowTexModal] = useState(false); // Modal to import ex_test LaTeX

  // Student Quiz Taking States
  const [quizStudentId, setQuizStudentId] = useState("");
  const [quizClassId, setQuizClassId] = useState("");
  const [quizStarted, setQuizStarted] = useState(false);
  const [quizCurrentIndex, setQuizCurrentIndex] = useState(0);
  const [quizAnswers, setQuizAnswers] = useState({});
  const [quizTimeLeft, setQuizTimeLeft] = useState(0);
  const [quizResult, setQuizResult] = useState(null);

  // TeX import state
  const [texInputText, setTexInputText] = useState("");

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
        noi_dung: "Câu 1: Giá trị của hàm số $y = f(x) = 2x^2 + 3x - 5$ tại $x = 2$ là:",
        phuong_an: ["A. $9$", "B. $7$", "C. $11$", "D. $5$"],
        dap_an_dung: "A",
        giai_thich: "Thay $x = 2$ vào hàm số: $f(2) = 2\\cdot(2)^2 + 3\\cdot(2) - 5 = 8 + 6 - 5 = 9$. Chọn A.",
      },
      {
        loai_cau_hoi: "TRAC_NGHIEM_DUNG_SAI",
        noi_dung: "Câu 2: Cho phương trình bậc hai $x^2 - 5x + 6 = 0$. Xét tính đúng/sai của các mệnh đề sau:",
        y_hoi: [
          "a) Phương trình có biệt thức $\\Delta = 1 > 0$",
          "b) Tổng hai nghiệm $x_1 + x_2 = 5$",
          "c) Tích hai nghiệm $x_1 \\cdot x_2 = -6$",
          "d) Hai nghiệm của phương trình là $x_1 = 2$ và $x_2 = 3$",
        ],
        dap_an_dung: { 0: "DUNG", 1: "DUNG", 2: "SAI", 3: "DUNG" },
        giai_thich: "$\\Delta = (-5)^2 - 4\\cdot 1\\cdot 6 = 1 > 0$ (Đúng). Theo Vi-ét: $x_1+x_2 = 5$ (Đúng), $x_1\\cdot x_2 = 6$ (chứ không phải $-6 \\rightarrow$ Sai). Hai nghiệm là $2$ và $3$ (Đúng).",
      },
      {
        loai_cau_hoi: "TRA_LOI_NGAN",
        noi_dung: "Câu 3: Tính giá trị của biểu thức $A = \\sqrt{25} + 3\\sqrt{4}$. Điền kết quả số:",
        dap_an_dung: "11",
        giai_thich: "$A = 5 + 3\\cdot 2 = 5 + 6 = 11$. Kết quả số là 11.",
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

  // Seed Initial Exams for Demo if database is empty
  const seedInitialExams = async () => {
    const defaultExams = [
      {
        id: "de_toan9_dinh_cao",
        tieu_de: "Đề Kiểm Tra Tổng Hợp Môn Toán Khối 9 (Gồm 3 Dạng + Công Thức KaTeX)",
        mon: "TOAN",
        khoi: "9",
        loai: "KIEM_TRA",
        thoi_gian_phut: 45,
        lop_id: "ALL",
        mo_ta: "Đề kiểm tra chuẩn Bộ GD&ĐT tích hợp hiển thị công thức Toán học KaTeX linh hoạt.",
        created_at: new Date().toLocaleDateString("vi-VN"),
        cau_hoi: [
          {
            loai_cau_hoi: "TRAC_NGHIEM_4_DAP_AN",
            noi_dung: "Câu 1: Cho biểu thức $P = \\frac{\\sqrt{x}+1}{\\sqrt{x}-1}$ với $x \\ge 0, x \\neq 1$. Giá trị của $P$ tại $x = 4$ là:",
            phuong_an: ["A. $P = 3$", "B. $P = 2$", "C. $P = \\frac{1}{3}$", "D. $P = 5$"],
            dap_an_dung: "A",
            giai_thich: "Thay $x = 4$ vào biểu thức: $P = \\frac{\\sqrt{4}+1}{\\sqrt{4}-1} = \\frac{2+1}{2-1} = 3$. Chọn A.",
          },
          {
            loai_cau_hoi: "TRAC_NGHIEM_DUNG_SAI",
            noi_dung: "Câu 2: Cho tam giác $ABC$ vuông tại $A$ có $AB = 6\\text{ cm}, AC = 8\\text{ cm}$. Xét tính đúng/sai của các mệnh đề:",
            y_hoi: [
              "a) Cạnh huyền $BC = \\sqrt{AB^2 + AC^2} = 10\\text{ cm}$",
              "b) Đường cao $AH = \\frac{AB \\cdot AC}{BC} = 4{,}8\\text{ cm}$",
              "c) Diện tích tam giác $S_{ABC} = 48\\text{ cm}^2$",
              "d) Bán kính đường tròn ngoại tiếp $R = \\frac{BC}{2} = 5\\text{ cm}$",
            ],
            dap_an_dung: { 0: "DUNG", 1: "DUNG", 2: "SAI", 3: "DUNG" },
            giai_thich: "$BC = \\sqrt{6^2+8^2} = 10\\text{ cm}$ (Đúng). $AH = \\frac{6 \\cdot 8}{10} = 4{,}8\\text{ cm}$ (Đúng). $S = \\frac{1}{2} \\cdot 6 \\cdot 8 = 24\\text{ cm}^2$ (chứ không phải $48\\text{ cm}^2 \\rightarrow$ Sai). $R = \\frac{BC}{2} = 5\\text{ cm}$ (Đúng).",
          },
          {
            loai_cau_hoi: "TRA_LOI_NGAN",
            noi_dung: "Câu 3: Tìm giá trị của $x$ để căn thức $\\sqrt{2x - 10} = 0$. Điền kết quả số:",
            dap_an_dung: "5",
            giai_thich: "$\\sqrt{2x - 10} = 0 \\Leftrightarrow 2x - 10 = 0 \\Leftrightarrow x = 5$. Kết quả điền số là 5.",
          },
        ],
      },
      {
        id: "de_vatli10_3dang",
        tieu_de: "Đề Kiểm Tra Vật Lý 10 - Chuyển Động Thẳng Biến Đổi Đều",
        mon: "VAT_LI",
        khoi: "10",
        loai: "KIEM_TRA",
        thoi_gian_phut: 45,
        lop_id: "ALL",
        mo_ta: "Kiểm tra công thức chuyển động $v = v_0 + at$, $s = v_0 t + \\frac{1}{2}at^2$ Vật Lý 10.",
        created_at: new Date().toLocaleDateString("vi-VN"),
        cau_hoi: [
          {
            loai_cau_hoi: "TRAC_NGHIEM_4_DAP_AN",
            noi_dung: "Câu 1: Công thức tính vận tốc tức thời trong chuyển động thẳng biến đổi đều là:",
            phuong_an: ["A. $v = v_0 + at$", "B. $v = v_0 + \\frac{1}{2}at^2$", "C. $v = at$", "D. $v = v_0 - at^2$"],
            dap_an_dung: "A",
            giai_thich: "Vận tốc tức thời $v = v_0 + at$. Chọn A.",
          },
          {
            loai_cau_hoi: "TRAC_NGHIEM_DUNG_SAI",
            noi_dung: "Câu 2: Một vật gia tốc từ trạng thái nghỉ với gia tốc $a = 2\\text{ m/s}^2$. Đánh giá tính đúng/sai:",
            y_hoi: [
              "a) Vận tốc ban đầu $v_0 = 0\\text{ m/s}$",
              "b) Vận tốc sau $t = 5\\text{ s}$ đạt $v = 10\\text{ m/s}$",
              "c) Quãng đường sau $5\\text{ s}$ là $s = 25\\text{ m}$",
              "d) Gia tốc giảm dần theo thời gian",
            ],
            dap_an_dung: { 0: "DUNG", 1: "DUNG", 2: "DUNG", 3: "SAI" },
            giai_thich: "$v_0 = 0$ (Đúng). $v = 2\\cdot 5 = 10\\text{ m/s}$ (Đúng). $s = \\frac{1}{2}\\cdot 2 \\cdot 5^2 = 25\\text{ m}$ (Đúng). Gia tốc $a = 2\\text{ m/s}^2$ không đổi (Ý d Sai).",
          },
          {
            loai_cau_hoi: "TRA_LOI_NGAN",
            noi_dung: "Câu 3: Một xe hãm phanh với vận tốc ban đầu $v_0 = 4\\text{ m/s}$ dừng lại sau $2\\text{ s}$. Độ lớn gia tốc hãm phanh là bao nhiêu $\\text{m/s}^2$? Điền số:",
            dap_an_dung: "2",
            giai_thich: "$v = v_0 + at \\Rightarrow 0 = 4 + 2a \\Rightarrow a = -2\\text{ m/s}^2$. Độ lớn gia tốc hãm phanh là $2\\text{ m/s}^2$.",
          },
        ],
      },
    ];

    for (const ex of defaultExams) {
      await set(ref(db, `de_thi/${ex.id}`), ex);
    }
  };

  // Timer Effect for Active Quiz
  useEffect(() => {
    let timer = null;
    if (quizStarted && quizTimeLeft > 0 && !quizResult) {
      timer = setInterval(() => {
        setQuizTimeLeft((prev) => {
          if (prev <= 1) {
            clearInterval(timer);
            handleFinishQuiz();
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
    }
    return () => {
      if (timer) clearInterval(timer);
    };
  }, [quizStarted, quizTimeLeft, quizResult]);

  // Format Timer SS:MM
  const formatTimer = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
  };

  // Open Quiz Modal for Student
  const handleStartQuizModal = (exam) => {
    setActiveQuizExam(exam);
    setQuizStudentId("");
    setQuizClassId("");
    setQuizStarted(false);
    setQuizCurrentIndex(0);
    setQuizAnswers({});
    setQuizTimeLeft(exam.thoi_gian_phut * 60);
    setQuizResult(null);
  };

  // Finish Quiz & Submit Score
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

  // Create New Question in Teacher Form
  const handleAddQuestionToNewExam = (type = "TRAC_NGHIEM_4_DAP_AN") => {
    let newQ = {};

    if (type === "TRAC_NGHIEM_4_DAP_AN") {
      newQ = {
        loai_cau_hoi: "TRAC_NGHIEM_4_DAP_AN",
        noi_dung: `Câu ${newExam.cau_hoi.length + 1}: Nội dung câu hỏi trắc nghiệm $x + 1 = 2$...`,
        phuong_an: ["A. Phương án A", "B. Phương án B", "C. Phương án C", "D. Phương án D"],
        dap_an_dung: "A",
        giai_thich: "",
      };
    } else if (type === "TRAC_NGHIEM_DUNG_SAI") {
      newQ = {
        loai_cau_hoi: "TRAC_NGHIEM_DUNG_SAI",
        noi_dung: `Câu ${newExam.cau_hoi.length + 1}: Phát biểu sau đúng hay sai:`,
        y_hoi: [
          "a) Mệnh đề thứ nhất...",
          "b) Mệnh đề thứ hai...",
          "c) Mệnh đề thứ ba...",
          "d) Mệnh đề thứ tư...",
        ],
        dap_an_dung: { 0: "DUNG", 1: "SAI", 2: "DUNG", 3: "SAI" },
        giai_thich: "",
      };
    } else if (type === "TRA_LOI_NGAN") {
      newQ = {
        loai_cau_hoi: "TRA_LOI_NGAN",
        noi_dung: `Câu ${newExam.cau_hoi.length + 1}: Tính giá trị $A = \\int_0^1 x dx$. Điền số:`,
        dap_an_dung: "0.5",
        giai_thich: "",
      };
    }

    setNewExam((prev) => ({
      ...prev,
      cau_hoi: [...prev.cau_hoi, newQ],
    }));
  };

  // Remove Question from Form
  const handleRemoveQuestionFromNewExam = (index) => {
    setNewExam((prev) => ({
      ...prev,
      cau_hoi: prev.cau_hoi.filter((_, idx) => idx !== index),
    }));
  };

  // Save New Exam to Firebase
  const handleSaveNewExam = async (e) => {
    e.preventDefault();
    if (!newExam.tieu_de) {
      alert("Vui lòng nhập Tên Đề Thi / Bài Tập!");
      return;
    }

    const examId = `de_${Date.now()}`;
    const payload = {
      ...newExam,
      id: examId,
      created_at: new Date().toLocaleDateString("vi-VN"),
    };

    try {
      await set(ref(db, `de_thi/${examId}`), payload);
      setShowCreateModal(false);
      alert("Đã lưu đề thi mới thành công!");
    } catch (err) {
      console.error("Lỗi khi lưu đề thi:", err);
      alert("Đã xảy ra lỗi khi tạo đề thi.");
    }
  };

  // Delete Exam
  const handleDeleteExam = async (examId) => {
    if (confirm("Bạn có chắc chắn muốn xóa đề thi này? Hành động không thể hoàn tác.")) {
      try {
        await remove(ref(db, `de_thi/${examId}`));
      } catch (err) {
        console.error("Lỗi khi xóa đề thi:", err);
      }
    }
  };

  // TeX File Upload Handler
  const handleTexFileUpload = (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (evt) => {
      const text = evt.target.result;
      const parsedQuestions = parseExTest(text);
      if (parsedQuestions.length > 0) {
        setNewExam((prev) => ({
          ...prev,
          cau_hoi: parsedQuestions,
        }));
        setShowTexModal(false);
        alert(`Đã phân tích và nạp ${parsedQuestions.length} câu hỏi từ file TeX ex_test!`);
      } else {
        alert("Không tìm thấy cấu trúc câu hỏi \\begin{ex}...\\end{ex} hợp lệ trong file TeX!");
      }
    };
    reader.readAsText(file, "UTF-8");
  };

  // TeX Direct Text Parser Handler
  const handleParseTexText = () => {
    if (!texInputText.trim()) {
      alert("Vui lòng dán nội dung mã TeX gói lệnh ex_test!");
      return;
    }

    const parsedQuestions = parseExTest(texInputText);
    if (parsedQuestions.length > 0) {
      setNewExam((prev) => ({
        ...prev,
        cau_hoi: parsedQuestions,
      }));
      setTexInputText("");
      setShowTexModal(false);
      alert(`Đã phân tích và nạp ${parsedQuestions.length} câu hỏi thành công!`);
    } else {
      alert("Không tìm thấy khối câu hỏi \\begin{ex}...\\end{ex} hợp lệ.");
    }
  };

  // Filtered Exams
  const filteredExams = exams.filter((exam) => {
    const matchQuery =
      exam.tieu_de.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (exam.mo_ta && exam.mo_ta.toLowerCase().includes(searchQuery.toLowerCase()));

    const matchSubject = selectedSubject === "ALL" || exam.mon === selectedSubject;
    const matchGrade = selectedGrade === "ALL" || String(exam.khoi) === String(selectedGrade);
    const matchType = selectedType === "ALL" || exam.loai === selectedType;

    return matchQuery && matchSubject && matchGrade && matchType;
  });

  return (
    <div style={{ maxWidth: "1280px", margin: "0 auto", paddingBottom: "3rem" }}>
      {/* HEADER TITLE */}
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          marginBottom: "1.5rem",
          flexWrap: "wrap",
          gap: "1rem",
        }}
      >
        <div>
          <h1 style={{ fontSize: "1.6rem", fontWeight: "800", display: "flex", alignItems: "center", gap: "0.6rem" }}>
            <FileText size={28} color="var(--accent-primary)" /> Ngân Hàng Đề Thi & Bài Tập Trực Tuyến
          </h1>
          <p style={{ fontSize: "0.88rem", color: "var(--text-muted)", marginTop: "0.25rem" }}>
            Hỗ trợ 3 Dạng bài tập chuẩn Bộ GD&ĐT: Trắc nghiệm 4 đáp án, Trắc nghiệm Đúng/Sai & Trả lời ngắn (KaTeX Math + Nhập file TeX ex_test)
          </p>
        </div>

        <div style={{ display: "flex", gap: "0.75rem", flexWrap: "wrap" }}>
          <button
            type="button"
            onClick={() => setShowTexModal(true)}
            className="btn-secondary"
            style={{
              padding: "0.75rem 1.2rem",
              borderRadius: "var(--radius-md)",
              fontWeight: "700",
              display: "flex",
              alignItems: "center",
              gap: "0.5rem",
              borderColor: "var(--accent-primary)",
              color: "var(--accent-primary)",
            }}
          >
            <Sigma size={18} /> Nạp từ File / Mã TeX (ex_test)
          </button>

          <button
            type="button"
            onClick={() => setShowCreateModal(true)}
            className="btn-primary"
            style={{
              padding: "0.75rem 1.25rem",
              borderRadius: "var(--radius-md)",
              fontWeight: "700",
              display: "flex",
              alignItems: "center",
              gap: "0.5rem",
              boxShadow: "0 4px 15px var(--accent-glow)",
            }}
          >
            <Plus size={20} /> Tạo Đề Thi Mới
          </button>
        </div>
      </div>

      {/* FILTER & SEARCH BAR */}
      <div
        style={{
          backgroundColor: "var(--bg-card)",
          padding: "1.25rem",
          borderRadius: "var(--radius-lg)",
          border: "1px solid var(--border-color)",
          marginBottom: "1.75rem",
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))",
          gap: "1rem",
          alignItems: "center",
        }}
      >
        {/* Search */}
        <div style={{ position: "relative" }}>
          <Search
            size={18}
            style={{
              position: "absolute",
              left: "1rem",
              top: "50%",
              transform: "translateY(-50%)",
              color: "var(--text-muted)",
            }}
          />
          <input
            type="text"
            placeholder="Tìm đề thi, bài tập..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            style={{
              width: "100%",
              padding: "0.65rem 0.75rem 0.65rem 2.6rem",
              borderRadius: "var(--radius-md)",
              backgroundColor: "var(--bg-primary)",
              border: "1px solid var(--border-color)",
              color: "var(--text-primary)",
              outline: "none",
              fontSize: "0.9rem",
            }}
          />
        </div>

        {/* Filter Subject */}
        <div>
          <select
            value={selectedSubject}
            onChange={(e) => setSelectedSubject(e.target.value)}
            style={{
              width: "100%",
              padding: "0.65rem 0.75rem",
              borderRadius: "var(--radius-md)",
              backgroundColor: "var(--bg-primary)",
              border: "1px solid var(--border-color)",
              color: "var(--text-primary)",
              outline: "none",
              fontSize: "0.9rem",
            }}
          >
            <option value="ALL">📚 Tất cả Môn học</option>
            <option value="TOAN">📐 Môn TOÁN (Khối 6-12)</option>
            <option value="KHTN">🔬 Môn KHTN (Khối 6-9)</option>
            <option value="VAT_LI">⚡ Môn VẬT LÍ (Khối 10-12)</option>
          </select>
        </div>

        {/* Filter Grade */}
        <div>
          <select
            value={selectedGrade}
            onChange={(e) => setSelectedGrade(e.target.value)}
            style={{
              width: "100%",
              padding: "0.65rem 0.75rem",
              borderRadius: "var(--radius-md)",
              backgroundColor: "var(--bg-primary)",
              border: "1px solid var(--border-color)",
              color: "var(--text-primary)",
              outline: "none",
              fontSize: "0.9rem",
            }}
          >
            <option value="ALL">🏫 Tất cả Các Khối</option>
            <option value="6">Khối 6</option>
            <option value="7">Khối 7</option>
            <option value="8">Khối 8</option>
            <option value="9">Khối 9</option>
            <option value="10">Khối 10</option>
            <option value="11">Khối 11</option>
            <option value="12">Khối 12</option>
          </select>
        </div>

        {/* Filter Exam Type */}
        <div>
          <select
            value={selectedType}
            onChange={(e) => setSelectedType(e.target.value)}
            style={{
              width: "100%",
              padding: "0.65rem 0.75rem",
              borderRadius: "var(--radius-md)",
              backgroundColor: "var(--bg-primary)",
              border: "1px solid var(--border-color)",
              color: "var(--text-primary)",
              outline: "none",
              fontSize: "0.9rem",
            }}
          >
            <option value="ALL">📝 Tất cả Loại hình</option>
            <option value="BTVN">📝 Bài Tập Về Nhà (BTVN)</option>
            <option value="KIEM_TRA">⏱️ Đề Kiểm Tra Lấy Điểm</option>
            <option value="THI_THU">🎯 Đề Thi Thử Ôn Tập</option>
          </select>
        </div>
      </div>

      {/* EXAMS LIST GRID */}
      {loading ? (
        <div style={{ textAlign: "center", padding: "3rem 0", color: "var(--text-muted)" }}>
          Đang tải ngân hàng đề thi trực tuyến...
        </div>
      ) : filteredExams.length === 0 ? (
        <div
          style={{
            backgroundColor: "var(--bg-card)",
            borderRadius: "var(--radius-lg)",
            padding: "3rem 1.5rem",
            textAlign: "center",
            border: "1px solid var(--border-color)",
          }}
        >
          <HelpCircle size={48} color="var(--text-muted)" style={{ marginBottom: "1rem" }} />
          <h3 style={{ fontSize: "1.2rem", fontWeight: "700" }}>Không tìm thấy đề thi phù hợp</h3>
          <p style={{ color: "var(--text-muted)", fontSize: "0.9rem", marginTop: "0.25rem" }}>
            Thử thay đổi bộ lọc môn học, khối lớp hoặc tạo đề thi mới.
          </p>
        </div>
      ) : (
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fill, minmax(340px, 1fr))",
            gap: "1.25rem",
          }}
        >
          {filteredExams.map((exam) => {
            const numQuestions = (exam.cau_hoi || []).length;

            return (
              <div
                key={exam.id}
                style={{
                  backgroundColor: "var(--bg-card)",
                  borderRadius: "var(--radius-lg)",
                  border: "1px solid var(--border-color)",
                  padding: "1.25rem",
                  display: "flex",
                  flexDirection: "column",
                  justifyContent: "space-between",
                  transition: "all 0.25s ease",
                  boxShadow: "0 4px 12px rgba(0,0,0,0.05)",
                }}
              >
                <div>
                  {/* Badges Bar */}
                  <div style={{ display: "flex", gap: "0.4rem", flexWrap: "wrap", marginBottom: "0.75rem" }}>
                    <span
                      style={{
                        fontSize: "0.75rem",
                        padding: "0.2rem 0.6rem",
                        borderRadius: "12px",
                        fontWeight: "700",
                        backgroundColor:
                          exam.mon === "TOAN"
                            ? "rgba(13, 148, 136, 0.15)"
                            : exam.mon === "KHTN"
                            ? "rgba(16, 185, 129, 0.15)"
                            : "rgba(59, 130, 246, 0.15)",
                        color:
                          exam.mon === "TOAN"
                            ? "var(--accent-primary)"
                            : exam.mon === "KHTN"
                            ? "var(--success)"
                            : "var(--info)",
                      }}
                    >
                      {exam.mon === "TOAN" ? "📐 Môn TOÁN" : exam.mon === "KHTN" ? "🔬 Môn KHTN" : "⚡ Môn VẬT LÍ"}
                    </span>

                    <span
                      style={{
                        fontSize: "0.75rem",
                        padding: "0.2rem 0.6rem",
                        borderRadius: "12px",
                        fontWeight: "700",
                        backgroundColor: "var(--bg-secondary)",
                        color: "var(--text-primary)",
                      }}
                    >
                      Khối {exam.khoi}
                    </span>

                    <span
                      style={{
                        fontSize: "0.75rem",
                        padding: "0.2rem 0.6rem",
                        borderRadius: "12px",
                        fontWeight: "700",
                        backgroundColor:
                          exam.loai === "KIEM_TRA"
                            ? "rgba(239, 68, 68, 0.15)"
                            : exam.loai === "THI_THU"
                            ? "rgba(245, 158, 11, 0.15)"
                            : "rgba(13, 148, 136, 0.15)",
                        color:
                          exam.loai === "KIEM_TRA"
                            ? "var(--danger)"
                            : exam.loai === "THI_THU"
                            ? "var(--warning)"
                            : "var(--accent-primary)",
                      }}
                    >
                      {exam.loai === "KIEM_TRA"
                        ? "⏱️ Kiểm tra"
                        : exam.loai === "THI_THU"
                        ? "🎯 Thi thử"
                        : "📝 Bài tập về nhà"}
                    </span>
                  </div>

                  {/* Title */}
                  <h3
                    style={{
                      fontSize: "1.05rem",
                      fontWeight: "700",
                      lineHeight: "1.4",
                      marginBottom: "0.5rem",
                      color: "var(--text-primary)",
                    }}
                  >
                    <MathText text={exam.tieu_de} />
                  </h3>

                  {/* Description */}
                  {exam.mo_ta && (
                    <p
                      style={{
                        fontSize: "0.85rem",
                        color: "var(--text-muted)",
                        marginBottom: "1rem",
                        lineHeight: "1.4",
                      }}
                    >
                      <MathText text={exam.mo_ta} />
                    </p>
                  )}

                  {/* Meta Stats */}
                  <div
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: "1.25rem",
                      fontSize: "0.82rem",
                      color: "var(--text-secondary)",
                      paddingTop: "0.75rem",
                      borderTop: "1px dashed var(--border-color)",
                      marginBottom: "1.25rem",
                    }}
                  >
                    <div style={{ display: "flex", alignItems: "center", gap: "0.35rem" }}>
                      <Clock size={15} color="var(--accent-primary)" />
                      <span>{exam.thoi_gian_phut} Phút</span>
                    </div>

                    <div style={{ display: "flex", alignItems: "center", gap: "0.35rem" }}>
                      <ListCheck size={15} color="var(--success)" />
                      <span>{numQuestions} Câu hỏi (3 Dạng)</span>
                    </div>
                  </div>
                </div>

                {/* Card Action Buttons */}
                <div style={{ display: "flex", gap: "0.5rem" }}>
                  <button
                    type="button"
                    onClick={() => handleStartQuizModal(exam)}
                    className="btn-primary"
                    style={{
                      flex: 1,
                      padding: "0.65rem",
                      borderRadius: "var(--radius-md)",
                      fontWeight: "700",
                      fontSize: "0.88rem",
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      gap: "0.4rem",
                    }}
                  >
                    <PlayCircle size={16} /> Làm Bài Thi
                  </button>

                  <button
                    type="button"
                    onClick={() => setShowResultsModal(exam)}
                    className="btn-secondary"
                    style={{
                      padding: "0.65rem 0.85rem",
                      borderRadius: "var(--radius-md)",
                      fontWeight: "600",
                      fontSize: "0.85rem",
                      display: "flex",
                      alignItems: "center",
                      gap: "0.3rem",
                    }}
                    title="Xem điểm số học sinh"
                  >
                    <BarChart2 size={16} /> Bảng Điểm
                  </button>

                  <button
                    type="button"
                    onClick={() => handleDeleteExam(exam.id)}
                    style={{
                      padding: "0.65rem",
                      borderRadius: "var(--radius-md)",
                      backgroundColor: "rgba(239, 68, 68, 0.1)",
                      border: "1px solid rgba(239, 68, 68, 0.2)",
                      color: "var(--danger)",
                      cursor: "pointer",
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                    }}
                    title="Xóa đề thi"
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
            style={{
              backgroundColor: "var(--bg-card)",
              borderRadius: "var(--radius-lg)",
              border: "1px solid var(--border-color)",
              width: "100%",
              maxWidth: "840px",
              maxHeight: "92vh",
              overflowY: "auto",
              padding: "1.5rem",
              boxShadow: "0 10px 40px rgba(0,0,0,0.3)",
            }}
          >
            {/* Header */}
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.25rem", borderBottom: "1px solid var(--border-color)", paddingBottom: "1rem" }}>
              <div>
                <h3 style={{ fontSize: "1.2rem", fontWeight: "800" }}>
                  <MathText text={activeQuizExam.tieu_de} />
                </h3>
                <p style={{ fontSize: "0.8rem", color: "var(--text-muted)" }}>
                  Môn: {activeQuizExam.mon} | Khối: {activeQuizExam.khoi} | Thời gian: {activeQuizExam.thoi_gian_phut} Phút
                </p>
              </div>

              {!quizStarted && (
                <button
                  type="button"
                  onClick={() => setActiveQuizExam(null)}
                  style={{ background: "none", border: "none", color: "var(--text-muted)", cursor: "pointer", fontSize: "1.2rem" }}
                >
                  ✕
                </button>
              )}
            </div>

            {/* STEP A: Select Student & Class before starting */}
            {!quizStarted && (
              <div style={{ display: "flex", flexDirection: "column", gap: "1.25rem" }}>
                <div style={{ backgroundColor: "var(--bg-secondary)", padding: "1rem", borderRadius: "12px", border: "1px solid var(--border-color)" }}>
                  <label style={{ display: "block", fontSize: "0.88rem", fontWeight: "700", marginBottom: "0.5rem" }}>
                    1. Chọn Lớp Học *
                  </label>
                  <select
                    value={quizClassId}
                    onChange={(e) => {
                      setQuizClassId(e.target.value);
                      setQuizStudentId("");
                    }}
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
                    <option value="">-- Bấm chọn Lớp --</option>
                    {classes.map((cls) => (
                      <option key={cls.id || cls._key} value={cls.id || cls._key}>
                        {cls.ten || cls.ten_lop} ({cls.mon || "Lớp học"})
                      </option>
                    ))}
                  </select>
                </div>

                <div style={{ backgroundColor: "var(--bg-secondary)", padding: "1rem", borderRadius: "12px", border: "1px solid var(--border-color)" }}>
                  <label style={{ display: "block", fontSize: "0.88rem", fontWeight: "700", marginBottom: "0.5rem" }}>
                    2. Chọn Tên Học Sinh *
                  </label>
                  <select
                    value={quizStudentId}
                    onChange={(e) => setQuizStudentId(e.target.value)}
                    disabled={!quizClassId}
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
                    <option value="">-- Bấm chọn Tên Học Sinh --</option>
                    {students
                      .filter((s) => !quizClassId || String(s.lop_id || s.lop) === String(quizClassId))
                      .map((hs) => (
                        <option key={hs.id || hs._key} value={hs.id || hs._key}>
                          {hs.ten} ({hs.sdt_phuhuynh || hs.ma_hs || "Học sinh"})
                        </option>
                      ))}
                  </select>
                </div>

                <button
                  type="button"
                  disabled={!quizClassId || !quizStudentId}
                  onClick={() => setQuizStarted(true)}
                  className="btn-primary"
                  style={{
                    padding: "0.85rem",
                    borderRadius: "var(--radius-md)",
                    fontWeight: "800",
                    fontSize: "1rem",
                    marginTop: "0.5rem",
                    opacity: !quizClassId || !quizStudentId ? 0.5 : 1,
                  }}
                >
                  🚀 BẮT ĐẦU LÀM BÀI THI TÍNH GIỜ
                </button>
              </div>
            )}

            {/* STEP B: Quiz Answering UI */}
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
                        <MathText text={curQ.noi_dung} />
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
                                <MathText text={opt} />
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
                                <span style={{ fontSize: "0.92rem", fontWeight: "600", flex: 1 }}>
                                  <MathText text={subItem} />
                                </span>

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

                      {/* TYPE 3: SHORT ANSWER INPUT */}
                      {qType === "TRA_LOI_NGAN" && (
                        <div>
                          <label style={{ display: "block", fontSize: "0.85rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                            Nhập đáp án số hoặc văn bản từ bàn phím:
                          </label>
                          <input
                            type="text"
                            placeholder="Gõ đáp án của bạn vào đây (Ví dụ: 11 hoặc -2.5)..."
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
                              border: "2px solid var(--border-color)",
                              color: "var(--text-primary)",
                              outline: "none",
                              fontSize: "1rem",
                              fontWeight: "700",
                            }}
                          />
                        </div>
                      )}
                    </div>
                  )}

                  {/* Navigation Buttons */}
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                    <button
                      type="button"
                      disabled={quizCurrentIndex === 0}
                      onClick={() => setQuizCurrentIndex((prev) => Math.max(0, prev - 1))}
                      className="btn-secondary"
                      style={{ padding: "0.6rem 1.2rem", fontWeight: "700" }}
                    >
                      <ChevronLeft size={18} /> Câu trước
                    </button>

                    {quizCurrentIndex < questions.length - 1 ? (
                      <button
                        type="button"
                        onClick={() => setQuizCurrentIndex((prev) => Math.min(questions.length - 1, prev + 1))}
                        className="btn-primary"
                        style={{ padding: "0.6rem 1.2rem", fontWeight: "700" }}
                      >
                        Câu tiếp theo <ChevronRight size={18} />
                      </button>
                    ) : (
                      <button
                        type="button"
                        onClick={handleFinishQuiz}
                        className="btn-primary"
                        style={{
                          padding: "0.6rem 1.5rem",
                          fontWeight: "800",
                          backgroundColor: "var(--success)",
                          boxShadow: "0 4px 15px rgba(16, 185, 129, 0.3)",
                        }}
                      >
                        ✅ NỘP BÀI THI
                      </button>
                    )}
                  </div>
                </div>
              );
            })()}

            {/* STEP C: Quiz Results & Detailed Solutions View */}
            {quizResult && (
              <div style={{ textAlign: "center", padding: "1rem 0" }}>
                <div
                  style={{
                    width: "72px",
                    height: "72px",
                    borderRadius: "50%",
                    backgroundColor: "rgba(16, 185, 129, 0.15)",
                    color: "var(--success)",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    margin: "0 auto 1rem auto",
                  }}
                >
                  <Award size={40} />
                </div>

                <h3 style={{ fontSize: "1.4rem", fontWeight: "800", marginBottom: "0.25rem" }}>
                  Kết Quả Nộp Bài Thi Thành Công!
                </h3>
                <p style={{ color: "var(--text-muted)", fontSize: "0.9rem", marginBottom: "1.25rem" }}>
                  Học sinh: <strong>{quizResult.submissionData.ten_hoc_sinh}</strong>
                </p>

                <div
                  style={{
                    backgroundColor: "var(--bg-primary)",
                    padding: "1.25rem",
                    borderRadius: "16px",
                    border: "1px solid var(--border-color)",
                    display: "inline-block",
                    marginBottom: "1.5rem",
                  }}
                >
                  <div style={{ fontSize: "0.85rem", color: "var(--text-muted)" }}>ĐIỂM SỐ ĐẠT ĐƯỢC</div>
                  <div style={{ fontSize: "2.8rem", fontWeight: "900", color: "var(--accent-primary)" }}>
                    {quizResult.score} / 10.0
                  </div>
                </div>

                {/* Detailed Answers Review */}
                <h4 style={{ textAlign: "left", fontSize: "1rem", fontWeight: "700", marginBottom: "1rem", borderTop: "1px solid var(--border-color)", paddingTop: "1rem" }}>
                  Chi Tiết Đáp Án & Lời Giải Hướng Dẫn:
                </h4>

                <div style={{ display: "flex", flexDirection: "column", gap: "1rem", marginBottom: "1.5rem", textAlign: "left" }}>
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
                          <MathText text={q.noi_dung} />
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
                                  - <MathText text={y} />: Bạn chọn <strong>{stdSub || "Chưa chọn"}</strong> (Đáp án đúng: <strong>{expSub}</strong>) {isMatch ? "✓" : "✗"}
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

                        {(q.giai_thich || q.loi_giai) && (
                          <div style={{ backgroundColor: "rgba(13, 148, 136, 0.1)", padding: "0.65rem 0.85rem", borderRadius: "8px", fontSize: "0.85rem", color: "var(--accent-primary)", marginTop: "0.5rem" }}>
                            💡 <strong>Lời giải chi tiết:</strong> <MathText text={q.giai_thich || q.loi_giai} />
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
            style={{
              backgroundColor: "var(--bg-card)",
              borderRadius: "var(--radius-lg)",
              border: "1px solid var(--border-color)",
              width: "100%",
              maxWidth: "760px",
              maxHeight: "90vh",
              overflowY: "auto",
              padding: "1.5rem",
            }}
          >
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem", borderBottom: "1px solid var(--border-color)", paddingBottom: "0.75rem" }}>
              <h3 style={{ fontSize: "1.2rem", fontWeight: "800" }}>
                Bảng Điểm: <MathText text={showResultsModal.tieu_de} />
              </h3>
              <button
                type="button"
                onClick={() => setShowResultsModal(null)}
                style={{ background: "none", border: "none", color: "var(--text-muted)", cursor: "pointer", fontSize: "1.2rem" }}
              >
                ✕
              </button>
            </div>

            {(() => {
              const examSubmissions = submissions.filter((sub) => String(sub.exam_id) === String(showResultsModal.id));

              if (examSubmissions.length === 0) {
                return (
                  <div style={{ textAlign: "center", padding: "2.5rem 0", color: "var(--text-muted)" }}>
                    Chưa có học sinh nào nộp bài thi này.
                  </div>
                );
              }

              return (
                <table style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.9rem" }}>
                  <thead>
                    <tr style={{ backgroundColor: "var(--bg-primary)", borderBottom: "2px solid var(--border-color)" }}>
                      <th style={{ padding: "0.75rem", textAlign: "left" }}>Tên Học Sinh</th>
                      <th style={{ padding: "0.75rem", textAlign: "center" }}>Điểm Số</th>
                      <th style={{ padding: "0.75rem", textAlign: "right" }}>Thời Gian Nộp</th>
                    </tr>
                  </thead>
                  <tbody>
                    {examSubmissions.map((sub, idx) => (
                      <tr key={idx} style={{ borderBottom: "1px solid var(--border-color)" }}>
                        <td style={{ padding: "0.75rem", fontWeight: "700" }}>{sub.ten_hoc_sinh}</td>
                        <td style={{ padding: "0.75rem", textAlign: "center", fontWeight: "800", color: "var(--accent-primary)" }}>
                          {sub.diem_so} / 10.0
                        </td>
                        <td style={{ padding: "0.75rem", textAlign: "right", color: "var(--text-muted)", fontSize: "0.82rem" }}>
                          {sub.ngay_nop}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              );
            })()}
          </div>
        </div>
      )}

      {/* MODAL 3: IMPORT TEX FILE / EX_TEST CONTENT MODAL */}
      {showTexModal && (
        <div
          style={{
            position: "fixed",
            inset: 0,
            backgroundColor: "rgba(0, 0, 0, 0.75)",
            backdropFilter: "blur(4px)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            zIndex: 110,
            padding: "1rem",
          }}
        >
          <div
            style={{
              backgroundColor: "var(--bg-card)",
              borderRadius: "var(--radius-lg)",
              border: "1px solid var(--border-color)",
              width: "100%",
              maxWidth: "680px",
              maxHeight: "90vh",
              overflowY: "auto",
              padding: "1.5rem",
            }}
          >
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem" }}>
              <h3 style={{ fontSize: "1.2rem", fontWeight: "800", display: "flex", alignItems: "center", gap: "0.5rem" }}>
                <Sigma color="var(--accent-primary)" /> Nạp Bài Tập Từ File TeX (Gói ex_test)
              </h3>
              <button
                type="button"
                onClick={() => setShowTexModal(false)}
                style={{ background: "none", border: "none", color: "var(--text-muted)", cursor: "pointer", fontSize: "1.2rem" }}
              >
                ✕
              </button>
            </div>

            <p style={{ fontSize: "0.85rem", color: "var(--text-muted)", marginBottom: "1.25rem", lineHeight: "1.4" }}>
              Hệ thống tự động phân tích cấu trúc <code>\begin&#123;ex&#125; ... \end&#123;ex&#125;</code> bao gồm 3 dạng: Trắc nghiệm 4 đáp án (<code>\choice</code>), Trắc nghiệm Đúng/Sai (<code>\choiceTF</code>), Trả lời ngắn (<code>\shortans</code>) và Hướng dẫn giải (<code>\loigiai</code>).
            </p>

            {/* Option 1: File Upload */}
            <div style={{ backgroundColor: "var(--bg-secondary)", padding: "1.25rem", borderRadius: "12px", border: "2px dashed var(--border-color)", textAlign: "center", marginBottom: "1.25rem" }}>
              <FileUp size={32} color="var(--accent-primary)" style={{ marginBottom: "0.5rem" }} />
              <div style={{ fontSize: "0.95rem", fontWeight: "700", marginBottom: "0.25rem" }}>Cách 1: Chọn Tải Lên File .tex Hoặc .txt</div>
              <p style={{ fontSize: "0.78rem", color: "var(--text-muted)", marginBottom: "0.85rem" }}>Hỗ trợ UTF-8 chứa mã nguồn đề thi LaTeX</p>
              
              <label
                className="btn-primary"
                style={{
                  display: "inline-flex",
                  alignItems: "center",
                  gap: "0.5rem",
                  padding: "0.6rem 1.25rem",
                  cursor: "pointer",
                  fontWeight: "700",
                  fontSize: "0.88rem",
                }}
              >
                <Upload size={16} /> Chọn File .tex từ Máy Tính
                <input type="file" accept=".tex,.txt" onChange={handleTexFileUpload} style={{ display: "none" }} />
              </label>
            </div>

            {/* Option 2: Paste TeX Text */}
            <div>
              <label style={{ display: "block", fontSize: "0.88rem", fontWeight: "700", marginBottom: "0.4rem" }}>
                Cách 2: Dán Mã TeX Trực Tiếp Vào Ô Dưới Đây
              </label>
              <textarea
                rows={8}
                placeholder={`Ví dụ mã TeX ex_test:\n\\begin{ex}\nTính tích phân $I = \\int_0^1 x \\, dx$.\n\\choice\n{A. $I = \\frac{1}{3}$}\n{\\True B. $I = \\frac{1}{2}$}\n{C. $I = 1$}\n{D. $I = 2$}\n\\loigiai{Ta có $I = \\frac{1}{2}$. Chọn B.}\n\\end{ex}`}
                value={texInputText}
                onChange={(e) => setTexInputText(e.target.value)}
                style={{
                  width: "100%",
                  padding: "0.85rem",
                  borderRadius: "12px",
                  backgroundColor: "var(--bg-primary)",
                  border: "1px solid var(--border-color)",
                  color: "var(--text-primary)",
                  fontFamily: "monospace",
                  fontSize: "0.85rem",
                  outline: "none",
                  marginBottom: "1rem",
                }}
              />

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.5rem" }}>
                <button
                  type="button"
                  onClick={() => setShowTexModal(false)}
                  className="btn-secondary"
                  style={{ padding: "0.6rem 1.25rem", fontWeight: "600" }}
                >
                  Hủy
                </button>
                <button
                  type="button"
                  onClick={handleParseTexText}
                  className="btn-primary"
                  style={{ padding: "0.6rem 1.5rem", fontWeight: "700" }}
                >
                  ⚡ Phân Tích & Nạp Câu Hỏi
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 4: TEACHER CREATE / EDIT EXAM MODAL */}
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
            style={{
              backgroundColor: "var(--bg-card)",
              borderRadius: "var(--radius-lg)",
              border: "1px solid var(--border-color)",
              width: "100%",
              maxWidth: "900px",
              maxHeight: "92vh",
              overflowY: "auto",
              padding: "1.5rem",
            }}
          >
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.25rem", borderBottom: "1px solid var(--border-color)", paddingBottom: "0.75rem" }}>
              <h3 style={{ fontSize: "1.3rem", fontWeight: "800" }}>Soạn Thảo Đề Thi Mới</h3>
              <button
                type="button"
                onClick={() => setShowCreateModal(false)}
                style={{ background: "none", border: "none", color: "var(--text-muted)", cursor: "pointer", fontSize: "1.2rem" }}
              >
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
                                    updated[qIdx].phuong_an = ["A. ", "B. ", "C. ", "D. "];
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
                                fontSize: "0.78rem",
                                fontWeight: "700",
                              }}
                            >
                              <option value="TRAC_NGHIEM_4_DAP_AN">Dạng 1: Trắc nghiệm 4 đáp án</option>
                              <option value="TRAC_NGHIEM_DUNG_SAI">Dạng 2: Đúng / Sai</option>
                              <option value="TRA_LOI_NGAN">Dạng 3: Trả lời ngắn</option>
                            </select>
                          </div>

                          <button
                            type="button"
                            onClick={() => handleRemoveQuestionFromNewExam(qIdx)}
                            style={{
                              background: "none",
                              border: "none",
                              color: "var(--danger)",
                              cursor: "pointer",
                            }}
                            title="Xóa câu hỏi này"
                          >
                            <Trash2 size={16} />
                          </button>
                        </div>

                        {/* Question Content Input */}
                        <div style={{ marginBottom: "0.75rem" }}>
                          <textarea
                            rows={2}
                            placeholder="Nhập nội dung câu hỏi (Có thể gõ KaTeX như $x^2 + 1 = 0$)..."
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
                              padding: "0.6rem 0.75rem",
                              borderRadius: "8px",
                              backgroundColor: "var(--bg-secondary)",
                              border: "1px solid var(--border-color)",
                              color: "var(--text-primary)",
                              fontSize: "0.9rem",
                              outline: "none",
                            }}
                          />
                          <div style={{ fontSize: "0.82rem", color: "var(--accent-primary)", padding: "0.35rem 0.6rem", backgroundColor: "var(--bg-secondary)", borderRadius: "6px", marginTop: "0.3rem" }}>
                            👀 Xem trước KaTeX: <MathText text={q.noi_dung} />
                          </div>
                        </div>

                        {/* OPTIONS EDIT BY TYPE */}
                        {qType === "TRAC_NGHIEM_4_DAP_AN" && (
                          <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem", marginBottom: "0.75rem" }}>
                            {(q.phuong_an || ["A. ", "B. ", "C. ", "D. "]).map((opt, oIdx) => (
                              <div key={oIdx} style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                                <input
                                  type="text"
                                  value={opt}
                                  onChange={(e) => {
                                    const val = e.target.value;
                                    setNewExam((prev) => {
                                      const updated = [...prev.cau_hoi];
                                      const newOpts = [...(updated[qIdx].phuong_an || [])];
                                      newOpts[oIdx] = val;
                                      updated[qIdx].phuong_an = newOpts;
                                      return { ...prev, cau_hoi: updated };
                                    });
                                  }}
                                  style={{
                                    flex: 1,
                                    padding: "0.5rem 0.75rem",
                                    borderRadius: "8px",
                                    backgroundColor: "var(--bg-secondary)",
                                    border: "1px solid var(--border-color)",
                                    color: "var(--text-primary)",
                                    fontSize: "0.88rem",
                                  }}
                                />
                                <label style={{ fontSize: "0.8rem", cursor: "pointer", display: "flex", alignItems: "center", gap: "0.2rem" }}>
                                  <input
                                    type="radio"
                                    name={`correct_${qIdx}`}
                                    checked={q.dap_an_dung === opt.charAt(0)}
                                    onChange={() => {
                                      setNewExam((prev) => {
                                        const updated = [...prev.cau_hoi];
                                        updated[qIdx].dap_an_dung = opt.charAt(0);
                                        return { ...prev, cau_hoi: updated };
                                      });
                                    }}
                                  />
                                  Đúng
                                </label>
                              </div>
                            ))}
                          </div>
                        )}

                        {qType === "TRAC_NGHIEM_DUNG_SAI" && (
                          <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem", marginBottom: "0.75rem" }}>
                            {(q.y_hoi || ["a) ", "b) ", "c) ", "d) "]).map((yItem, sIdx) => {
                              const curSubAns = (q.dap_an_dung || {})[sIdx] || "DUNG";

                              return (
                                <div key={sIdx} style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                                  <input
                                    type="text"
                                    value={yItem}
                                    onChange={(e) => {
                                      const val = e.target.value;
                                      setNewExam((prev) => {
                                        const updated = [...prev.cau_hoi];
                                        const newSub = [...(updated[qIdx].y_hoi || [])];
                                        newSub[sIdx] = val;
                                        updated[qIdx].y_hoi = newSub;
                                        return { ...prev, cau_hoi: updated };
                                      });
                                    }}
                                    style={{
                                      flex: 1,
                                      padding: "0.5rem 0.75rem",
                                      borderRadius: "8px",
                                      backgroundColor: "var(--bg-secondary)",
                                      border: "1px solid var(--border-color)",
                                      color: "var(--text-primary)",
                                      fontSize: "0.88rem",
                                    }}
                                  />

                                  <select
                                    value={curSubAns}
                                    onChange={(e) => {
                                      const val = e.target.value;
                                      setNewExam((prev) => {
                                        const updated = [...prev.cau_hoi];
                                        const curAnsObj = { ...(updated[qIdx].dap_an_dung || {}) };
                                        curAnsObj[sIdx] = val;
                                        updated[qIdx].dap_an_dung = curAnsObj;
                                        return { ...prev, cau_hoi: updated };
                                      });
                                    }}
                                    style={{
                                      padding: "0.4rem 0.6rem",
                                      borderRadius: "6px",
                                      backgroundColor: curSubAns === "DUNG" ? "rgba(16, 185, 129, 0.2)" : "rgba(239, 68, 68, 0.2)",
                                      color: curSubAns === "DUNG" ? "var(--success)" : "var(--danger)",
                                      fontWeight: "700",
                                      fontSize: "0.8rem",
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

                        {qType === "TRA_LOI_NGAN" && (
                          <div style={{ marginBottom: "0.75rem" }}>
                            <label style={{ display: "block", fontSize: "0.8rem", fontWeight: "700", marginBottom: "0.25rem" }}>
                              Đáp án chuẩn cần điền:
                            </label>
                            <input
                              type="text"
                              value={q.dap_an_dung || ""}
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
                                padding: "0.5rem 0.75rem",
                                borderRadius: "8px",
                                backgroundColor: "var(--bg-secondary)",
                                border: "1px solid var(--border-color)",
                                color: "var(--text-primary)",
                                fontSize: "0.88rem",
                                fontWeight: "700",
                              }}
                            />
                          </div>
                        )}

                        {/* Explanation Input */}
                        <div>
                          <input
                            type="text"
                            placeholder="Lời giải chi tiết (Ví dụ: Thay x = 2 vào hàm số ta được...)..."
                            value={q.giai_thich || q.loi_giai || ""}
                            onChange={(e) => {
                              const val = e.target.value;
                              setNewExam((prev) => {
                                const updated = [...prev.cau_hoi];
                                updated[qIdx].giai_thich = val;
                                updated[qIdx].loi_giai = val;
                                return { ...prev, cau_hoi: updated };
                              });
                            }}
                            style={{
                              width: "100%",
                              padding: "0.45rem 0.65rem",
                              borderRadius: "6px",
                              backgroundColor: "var(--bg-secondary)",
                              border: "1px solid var(--border-color)",
                              color: "var(--text-primary)",
                              fontSize: "0.82rem",
                            }}
                          />
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Form Action Buttons */}
              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "1rem" }}>
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  className="btn-secondary"
                  style={{ padding: "0.75rem 1.5rem", fontWeight: "600" }}
                >
                  Hủy Bỏ
                </button>

                <button
                  type="submit"
                  className="btn-primary"
                  style={{ padding: "0.75rem 2rem", fontWeight: "700" }}
                >
                  💾 Lưu & Xuất Đề Thi
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
