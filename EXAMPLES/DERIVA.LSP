; Aritmetica simbolica - Derivadas


(DEFUN SUMP (E)
  (COND ((ATOM E) NIL)
        (T (EQ (CAR E) '+))))
(DEFUN PRODP (E)
  (COND ((ATOM E) NIL)
        (T (EQ (CAR E) '*))))
(DEFUN ARG1 (E) (CAR (CDR E)))
(DEFUN ARG2 (E) (CAR (CDR (CDR E))))

(DEFUN SUMASIMP (A B)
  (COND ((AND (NUMBERP A) (NUMBERP B)) (+ A B))
        ((AND (NUMBERP A) (= A 0)) B)
        ((AND (NUMBERP B) (= B 0)) A)
        (T (CONS '+ (CONS A (CONS B NIL))))))

(DEFUN PRODSIMP (A B)
  (COND ((AND (NUMBERP A) (NUMBERP B)) (* A B))
        ((AND (NUMBERP A) (= A 0)) 0)
        ((AND (NUMBERP B) (= B 0)) 0)
        ((AND (NUMBERP A) (= A 1)) B)
        ((AND (NUMBERP B) (= B 1)) A)
        (T (CONS '* (CONS A (CONS B NIL))))))

(DEFUN DERIV (E X)
  (COND
    ((ATOM E)
     (COND ((EQ E X) 1)
           (T 0)))
    ((SUMP E)
     (SUMASIMP (DERIV (ARG1 E) X)
               (DERIV (ARG2 E) X)))
    ((PRODP E)
     (SUMASIMP
       (PRODSIMP (ARG1 E) (DERIV (ARG2 E) X))
       (PRODSIMP (DERIV (ARG1 E) X) (ARG2 E))))
    (T 0)))


