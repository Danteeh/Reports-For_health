import pymupdf, sys, json

PDF = r"C:\Users\Danteeh\.kiro\crew\uploads\b3067465dffc44c9869fc577a28e0122_MTNE-RG-06_REPORTE_DE_MANTENIMIENTO_BTL_6000_ONDA_DE_CHOQUE_04400B012485.pdf"

doc = pymupdf.open(PDF)
print("PAGES:", doc.page_count)
for pno in range(doc.page_count):
    p = doc[pno]
    print(f"=== PAGE {pno+1} size {p.rect.width} x {p.rect.height} ===")
    print(p.get_text())
    print("--- /page ---")
