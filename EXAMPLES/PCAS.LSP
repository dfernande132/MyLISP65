; ===========================================================
; PCAS10 - Pruebas del Capitulo 10
; (identico al PCAS.lisp maestro en su estado actual)

; -- Capitulo 2: SUBST y EVALEXPR --

(DEFINE E1 (MAKESUM 'X 3))
(SUBST E1 'X 5)              ; -> 8 (desde el Cap.4, MAKESUM combina constantes)
(EVALEXPR (SUBST E1 'X 5))   ; -> 8

(DEFINE E2 (MAKEPROD (MAKESUM 'X 1) 'Y))
(SUBST E2 'X 2)                ; -> (* 3 Y) (Cap.4: MAKESUM combina 2+1)
(SUBST (SUBST E2 'X 2) 'Y 10)               ; -> 30 (MAKEPROD combina 3*10)
(EVALEXPR (SUBST (SUBST E2 'X 2) 'Y 10))   ; -> 30

(DEFINE E3 (MAKEPOW 'X 2))
(SUBST E3 'X 4)                     ; -> 16 (Cap.4: MAKEPOW combina 4^2)
(EVALEXPR (SUBST E3 'X 4))                 ; -> 16

(EVALEXPR 'Y)                 ; deberias ver los dos PRINT y -> VARLIBRE

(EVALEXPR (SUBST E2 'X 2))
; -> (* 3 Y), y al evaluarlo Y sigue libre dentro de un producto
; deberias ver los PRINT de Y y el resultado final -> VARLIBRE
; (NO un error de tipo del + o del *)

(LIBRE? (EVALEXPR 'Y))     ; -> T
(LIBRE? (EVALEXPR 5))      ; -> NIL

; -- Capitulo 3: DERIV --
; NOTA: como CAS.lisp es un fichero unico acumulativo, MAKESUM/MAKEPROD/
; MAKEPOW ya son la version inteligente del Cap.4 cuando se ejecuta esto.
; La salida "cruda" descrita en el capitulo 3 (p.ej. (+ 1 0)) solo se
; puede ver historicamente en ese capitulo, no reproduciendola aqui.

(DERIV '(+ X 3) 'X)             ; -> 1
(DERIV (MAKEPROD 'X 'X) 'X)     ; -> (+ X X)
(DERIV (MAKEPOW 'X 2) 'X)       ; -> (* 2 X)

; derivada segunda, para ver la explosion crecer (Cap.3) o, con los
; constructores inteligentes ya cargados, el resultado ya limpio (Cap.4)
(DERIV (DERIV (MAKEPROD 'X 'X) 'X) 'X)    ; -> 2  (d2/dx2(x*x) = 2, correcto)

; -- Capitulo 4: Constructores inteligentes --

(MAKESUM 2 3)                  ; -> 5
(MAKESUM 'X 0)                  ; -> X
(MAKESUM 0 'X)                  ; -> X
(MAKEPROD 'X 0)                  ; -> 0
(MAKEPROD 'X 1)                  ; -> X
(MAKEPOW 'X 0)                  ; -> 1
(MAKEPOW 'X 1)                  ; -> X
(MAKEPOW 1 'X)                  ; -> 1   (nueva regla: base 1)
(MAKEPOW 0 'X)                  ; -> (POT 0 X)   (NO se simplifica)
(MAKEPOW 2 3)                  ; -> 8

; -- Capitulo 5: SIMPSUM (orden canonico y terminos semejantes) --

(COEF (MAKEPROD 2 'X))          ; -> 2
(LITERAL (MAKEPROD 2 'X))       ; -> X
(COEF (MAKEPROD 'X 2))          ; -> 2
(LITERAL (MAKEPROD 'X 2))       ; -> X

(SIMPSUM '(+ (+ X Y) X))        ; -> (+ (* 2 X) Y)
(SIMPSUM '(+ X X))              ; -> (* 2 X)

; cerrando el hilo desde el Capitulo 3
(SIMPSUM (DERIV (MAKEPROD 'X 'X) 'X))    ; -> (* 2 X)

(SIMPSUM '(+ (+ (* 2 X) (* 3 X)) Y))    ; -> (+ (* 5 X) Y)
(SIMPSUM '(+ X (* X 2)))                 ; -> (* 3 X)

; cancelacion total de terminos (coeficiente resultante 0)
(SIMPSUM '(+ (+ X (* -1 X)) Y))    ; -> Y
(SIMPSUM '(+ X (* -1 X)))          ; -> 0

; -- Capitulo 6: SIMP (simplificacion de arbol completo) --

(SIMP '(* 2 (+ X X)))         ; -> (* 4 X) (antes Cap.7: (* 2 (* 2 X)))

(DEFINE E4 (MAKEPOW (MAKESUM 'X 'Y) 2))
(DERIV E4 'X)                       ; -> (* 2 (+ X Y))
(SIMP (DERIV E4 'X))            ; -> (* 2 (+ X Y)) (orden estable, Cap.9)

(DEFINE E5 (MAKESUM (MAKEPROD 'X 'X) (MAKEPROD 'X 'X)))
(DERIV E5 'X)                       ; -> (+ (+ X X) (+ X X))
(SIMP (DERIV E5 'X))                ; -> (* 4 X)

; -- Capitulo 7: SIMPPROD (simplificador de productos) --

(SIMPPROD '(* 2 (* 2 X)))          ; -> (* 4 X)
(SIMPPROD '(* X X))                ; -> (POT X 2)
(SIMPPROD '(* (* X X) X))          ; -> (POT X 3)

; regresion: casos ya conocidos no deben romperse
(SIMP (DERIV (MAKEPROD 'X 'X) 'X)) ; -> (* 2 X)
(SIMP (DERIV E5 'X))                ; -> (* 4 X)

; -- Capitulo 8: DERIVA y DERIVAEN (orquestador) --

(DEFINE E7 (MAKEPOW 'X 2))
(DERIVA E7 'X)              ; -> (* 2 X)
(DERIVAEN E7 'X 5)          ; -> 10

(DEFINE E8 (MAKEPROD 'X 'X))
(DERIVA E8 'X)              ; -> (* 2 X)
(DERIVAEN E8 'X 5)          ; -> 10

; composicion manual con dos variables (E4 ya es (X+Y)^2, del Cap.6)
(DERIVA E4 'X)                                       ; -> (* 2 (+ X Y))
(EVALEXPR (SUBST (SUBST (DERIVA E4 'X) 'X 3) 'Y 4))  ; -> 14

; derivada parcial mixta: f(X,Y) = X^2 * Y^3
(DEFINE F (MAKEPROD (MAKEPOW 'X 2) (MAKEPOW 'Y 3)))
(DEFINE DFDX (DERIVA F 'X))
DFDX                        ; -> (* 2 (* X (POT Y 3)))
(DEFINE D2F (DERIVA DFDX 'Y))
D2F                         ; -> (* 6 (* X (POT Y 2)))
(EVALEXPR (SUBST (SUBST D2F 'X 3) 'Y 5))
; -> 450

; -- Capitulo 9: EXPLESS? (orden canonico estable) --

; la misma suma, en tres ordenes de entrada distintos: mismo resultado
(SIMPSUM '(+ (+ X Y) X))    ; -> (+ (* 2 X) Y)
(SIMPSUM '(+ Y (+ X X)))    ; -> (+ (* 2 X) Y)
(SIMPSUM '(+ (+ Y X) X))    ; -> (+ (* 2 X) Y)

; simbolos de mas de una letra: orden alfabetico real (gracias a STR<,
; anadida al interprete tras descubrir que RANGOVAR no bastaba)
(SIMPSUM '(+ TIEMPO MASA))    ; -> (+ MASA TIEMPO)
(SIMPSUM '(+ MASA TIEMPO))    ; -> (+ MASA TIEMPO)

; las dos primitivas nuevas, sueltas
(STR< 'MASA 'TIEMPO)          ; -> T
(SYMNAME 'X)                  ; -> "X"

; EXPLESS?, suelto: constantes antes que variables, y alfabetico real
(EXPLESS? 3 5)                ; -> T
(EXPLESS? 3 'X)                ; -> T   (constante siempre antes que variable)
(EXPLESS? 'X 3)                ; -> NIL
(EXPLESS? 'A 'B)                ; -> T
(EXPLESS? 'B 'A)                ; -> NIL

; INSERTA, suelto: insertar en una lista de asociacion ya ordenada
(INSERTA (CONS 'B 1) (LIST (CONS 'A 1) (CONS 'C 1)))
; -> ((A . 1) (B . 1) (C . 1))

; ORDENA, suelto: ordenar una lista de asociacion cualquiera
(ORDENA (LIST (CONS 'Y 1) (CONS 'X 2)))
; -> ((X . 2) (Y . 1))
(ORDENA (LIST (CONS 'Z 1) (CONS 'A 5) (CONS 'M 3)))
; -> ((A . 5) (M . 3) (Z . 1))
(ORDENA NIL)
; -> NIL

; -- Capitulo 10: PRINTMAT (impresion infija) --

(PRINTMAT (MAKESUM (MAKEPROD 2 'X) 'Y))          ; 2x + y
(PRINTMAT (MAKEPROD 2 (MAKESUM 'X 'Y)))          ; 2(x + y)
(PRINTMAT (MAKESUM 2 (MAKEPROD 'X 'Y)))          ; 2 + x*y
(PRINTMAT (MAKEPOW (MAKEPOW 'X 2) 3))            ; (x^2)^3
(PRINTMAT (MAKEPOW 'X (MAKEPOW 'Y 2)))           ; x^y^2
(PRINTMAT (MAKESUM 'X (MAKEPROD -1 'Y)))         ; x - y
(PRINTMAT (MAKEPROD -1 (MAKESUM 'X 'Y)))         ; -(x + y)

; el cierre real: la derivada del Capitulo 8 (E7 = X^2), impresa
(PRINTMAT (DERIVA E7 'X))                         ; 2x

; la derivada parcial mixta del Capitulo 8/9
(PRINTMAT (DERIVA (DERIVA F 'X) 'Y))              ; 6x*y^2
