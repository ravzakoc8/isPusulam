package com.ispusulam;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

/** Gelen JSON'dan değer okumayı ve hata fırlatmayı kolaylaştıran küçük fonksiyonlar. */
public class Yardimci {

    /** JSON'daki yazıyı okur; yoksa veya boşsa null döner. */
    public static String metin(Map<String, Object> govde, String anahtar) {
        Object o = govde.get(anahtar);
        if (o == null) return null;
        String s = o.toString().trim();
        return s.isEmpty() ? null : s;
    }

    /** Zorunlu alan: yoksa 400 hatası fırlatır, mesaj Flutter'da ekrana çıkar. */
    public static String zorunlu(Map<String, Object> govde, String anahtar, String hataMesaji) {
        String s = metin(govde, anahtar);
        if (s == null) throw hata(HttpStatus.BAD_REQUEST, hataMesaji);
        return s;
    }

    public static ResponseStatusException hata(HttpStatus durum, String mesaj) {
        return new ResponseStatusException(durum, mesaj);
    }

    /** Veritabanından gelen sayıyı (Integer/Long) int'e çevirir. */
    public static int sayi(Object o) {
        return ((Number) o).intValue();
    }
}
