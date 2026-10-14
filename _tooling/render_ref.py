import pymupdf, os

PDF = r"C:\Users\Danteeh\.kiro\crew\uploads\b3067465dffc44c9869fc577a28e0122_MTNE-RG-06_REPORTE_DE_MANTENIMIENTO_BTL_6000_ONDA_DE_CHOQUE_04400B012485.pdf"
OUT = r"E:\Andres_Korea\_tooling\ref"
os.makedirs(OUT, exist_ok=True)

doc = pymupdf.open(PDF)
for pno in range(doc.page_count):
    p = doc[pno]
    pix = p.get_pixmap(matrix=pymupdf.Matrix(2.5, 2.5))
    pix.save(os.path.join(OUT, f"page{pno+1}.png"))
    # dump drawings (rects/lines) to understand table structure
    draws = p.get_drawings()
    with open(os.path.join(OUT, f"page{pno+1}_rects.txt"), "w", encoding="utf-8") as f:
        for d in draws:
            for item in d["items"]:
                if item[0] == "re":
                    r = item[1]
                    f.write(f"RECT x0={r.x0:.1f} y0={r.y0:.1f} x1={r.x1:.1f} y1={r.y1:.1f}\n")
                elif item[0] == "l":
                    a, b = item[1], item[2]
                    f.write(f"LINE {a.x:.1f},{a.y:.1f} -> {b.x:.1f},{b.y:.1f}\n")

# extract embedded images
for i, img in enumerate(doc.get_page_images(0)):
    xref = img[0]
    pix = pymupdf.Pixmap(doc, xref)
    if pix.n > 4:
        pix = pymupdf.Pixmap(pymupdf.csRGB, pix)
    pix.save(os.path.join(OUT, f"logo_{xref}.png"))
    print("saved logo xref", xref, pix.width, "x", pix.height)
print("done, rendered", doc.page_count, "pages")
