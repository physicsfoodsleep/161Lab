from random import random

# List of names imported from this module with import *
__all__ = ['adjust_axis', 'adjust_up', 'comp', 'cross', 'diff_angle', 'dot',
           'hat', 'mag', 'mag2', 'norm', 'object_rotate', 'proj', 'rotate',
           'vector']


cdef extern from "math.h":
    double cos(double theta)
    double sin(double theta)
    double acos(double theta)
    double sqrt(double x)
cdef double pi = 3.14159265358979323846

cdef class vector(object):

    cdef public double _x
    cdef public double _y
    cdef public double _z
    cdef public object on_change
    
    @staticmethod 
    def random():
        return vector(-1 + 2*random(), -1 + 2*random(), -1 + 2*random())

    def __init__(self, *args):
        if len(args) == 3:
            self._x = args[0] # make sure it's a float; could be numpy.float64?
            self._y = args[1]
            self._z = args[2]
        elif len(args) == 1 and isinstance(args[0], vector): # make a copy of a vector
            other = args[0]
            self._x = other.x
            self._y = other.y
            self._z = other.z
        else:
            raise TypeError('A vector needs 3 components.')
        self.on_change = self.ignore
        
    cpdef ignore(self):
        pass
            
    property value:
        def __get__(self):
            return [self.x, self.y, self.z]
        def __set__(self, other):
            self._x = other.x
            self._y = other.y
            self._z = other.z
        
    def __neg__(self):  ## seems like this must come before properties (???)
        return vector(-self.x, -self.y, -self.z)
    
    def __pos__(self):
        return self

    def __repr__(self):
        return '<{:.6g}, {:.6g}, {:.6g}>'.format(self._x, self._y, self._z)
    
    def __str__(self):
        return '<{:.6g}, {:.6g}, {:.6g}>'.format(self._x, self._y, self._z)

    def __add__(self,other):
        return vector(self.x + other.x, self.y + other.y, self.z + other.z)

    def __truediv__(self, other): # Python 3, or Python 2 + future division
        if isinstance(other, (int, float)):
            return vector(self.x / other, self.y / other, self.z / other)
        raise TypeError('a vector can only be divided by a scalar')

    def __div__(self, other): # Python 2 without future division
        if isinstance(other, (int, float)):
            return vector(self.x / other, self.y / other, self.z / other)
        raise TypeError('a vector can only be divided by a scalar')

    def __sub__(self,other):
        return vector(self.x - other.x, self.y - other.y, self.z - other.z)
    
    def __mul__(self, other):  ## in cython order of arguments is arbitrary, rmul doesn't exist
        if isinstance(other, (int, float)):
            return vector(self.x * other, self.y * other, self. z * other)
        elif isinstance(self, (int, float)):
            return vector(self * other.x, self * other.y, self * other.z)
        else:
            raise TypeError('a vector can only be multiplied by a scalar', self, other)
                  
    property x:
        def __get__(self):
            return self._x
        def __set__(self,value):
            self._x = value
            self.on_change()
    
    property y:
        def __get__(self):
            return self._y
        def __set__(self,value):
            self._y = value
            self.on_change()
    
    property z:
        def __get__(self):
            return self._z
        def __set__(self,value):
            self._z = value
            self.on_change()
        
    property mag:
        def __get__(self):
            return sqrt(self.x**2 + self.y**2 + self.z**2)
        def __set__(self, value):
            cdef vector normA
            normA = self.hat
            self.x = value * normA.x
            self.y = value * normA.y
            self.z = value * normA.z
            self.on_change()
            
    property mag2:
        def __get__(self):
            return (self.x**2 + self.y**2 + self.z**2)
        def __set__(self, value):
            cdef double v
            v = sqrt(value)
            self.mag = v
            self.on_change()
        
    property hat:
        def __get__(self):
            cdef double smag
            smag = self.mag
            if ( smag > 0. ):
                return self / smag
            else:
                return vector(0., 0., 0.)
        def __set__(self, value):
            cdef double smag
            smag = self.mag
            cdef vector normA
            normA = value.hat
            self.x = smag * normA.x
            self.y = smag * normA.y
            self.z = smag * normA.z
            self.on_change()
            

    cpdef vector norm(self):
        return self.hat

    cpdef double dot(self,other):
        return ( self.x*other.x + self.y*other.y + self.z*other.z )

    cpdef vector cross(self,other):
        return vector( self.y*other.z-self.z*other.y, 
                       self.z*other.x-self.x*other.z,
                       self.x*other.y-self.y*other.x )

    cpdef vector proj(self,other):
        cdef vector normB
        normB = other.hat
        return self.dot(normB) * normB
        
    cpdef bint equals(self,other):
        return ( self.x == other.x and self.y == other.y and self.z == other.z )

    cpdef double comp(self,other):  ## result is a scalar
        cdef vector normB
        normB = other.hat
        return self.dot(normB)

    cpdef double diff_angle(self, other):
        cdef double a
        a = self.hat.dot(other.hat)
        if a > 1:  # avoid roundoff problems
            return 0
        if a < -1:
            return pi
        return acos(a)

    cpdef vector rotate(self, double angle=0., vector axis=None):
        cdef vector u
        if axis == None:
            u = vector(0,0,1)
        else:
            u = axis.hat
        cdef double c = cos(angle)
        cdef double s = sin(angle)
        cdef double t = 1.0 - c
        cdef double x = u.x
        cdef double y = u.y
        cdef double z = u.z
        cdef double m11 = t*x*x+c
        cdef double m12 = t*x*y-z*s
        cdef double m13 = t*x*z+y*s
        cdef double m21 = t*x*y+z*s
        cdef double m22 = t*y*y+c
        cdef double m23 = t*y*z-x*s
        cdef double m31 = t*x*z-y*s
        cdef double m32 = t*y*z+x*s
        cdef double m33 = t*z*z+c
        cdef double sx = self.x
        cdef double sy = self.y
        cdef double sz = self.z
        return vector( (m11*sx + m12*sy + m13*sz),
                    (m21*sx + m22*sy + m23*sz),
                    (m31*sx + m32*sy + m33*sz) )
        
    cpdef rotate_in_place(self, double angle=0., vector axis=None):
        cdef vector u
        if axis == None:
            u = vector(0,0,1)
        else:
            u = axis.hat
        cdef double c = cos(angle)
        cdef double s = sin(angle)
        cdef double t = 1.0 - c
        cdef double x = u.x
        cdef double y = u.y
        cdef double z = u.z
        cdef double m11 = t*x*x+c
        cdef double m12 = t*x*y-z*s
        cdef double m13 = t*x*z+y*s
        cdef double m21 = t*x*y+z*s
        cdef double m22 = t*y*y+c
        cdef double m23 = t*y*z-x*s
        cdef double m31 = t*x*z-y*s
        cdef double m32 = t*y*z+x*s
        cdef double m33 = t*z*z+c
        cdef double sx = self.x
        cdef double sy = self.y
        cdef double sz = self.z
        self._x = m11*sx + m12*sy + m13*sz
        self._y = m21*sx + m22*sy + m23*sz
        self._z = m31*sx + m32*sy + m33*sz
                    
cpdef object_rotate(vector objaxis, vector objup, double angle, vector axis):
    cdef vector u = axis.hat
    cdef double c = cos(angle)
    cdef double s = sin(angle)
    cdef double t = 1.0 - c
    cdef double x = u.x
    cdef double y = u.y
    cdef double z = u.z
    cdef double m11 = t*x*x+c
    cdef double m12 = t*x*y-z*s
    cdef double m13 = t*x*z+y*s
    cdef double m21 = t*x*y+z*s
    cdef double m22 = t*y*y+c
    cdef double m23 = t*y*z-x*s
    cdef double m31 = t*x*z-y*s
    cdef double m32 = t*y*z+x*s
    cdef double m33 = t*z*z+c
    cdef double sx = objaxis.x
    cdef double sy = objaxis.y
    cdef double sz = objaxis.z
    objaxis._x = m11*sx + m12*sy + m13*sz # avoid creating a new vector object
    objaxis._y = m21*sx + m22*sy + m23*sz
    objaxis._z = m31*sx + m32*sy + m33*sz
    sx = objup.x
    sy = objup.y
    sz = objup.z
    objup._x = m11*sx + m12*sy + m13*sz
    objup._y = m21*sx + m22*sy + m23*sz
    objup._z = m31*sx + m32*sy + m33*sz

cpdef double mag(vector A):
    return A.mag

cpdef double mag2(vector A):
    return A.mag2

cpdef vector norm(vector A):
    return A.hat

cpdef vector hat(vector A):
    return A.hat

cpdef double dot(vector A, vector B):
    return A.dot(B)

cpdef vector cross(vector A, vector B):
    return A.cross(B)

cpdef vector proj(vector A, vector B):
    return A.proj(B)

cpdef double comp(vector A, vector B):
    return A.comp(B)

cpdef double diff_angle(vector A, vector B):
    return A.diff_angle(B)
                            
cpdef vector rotate(vector A, double angle = 0., vector axis = None):
    if axis is None:
        axis = vector(0,0,1)
    return A.rotate(angle=angle, axis=axis)
        
cpdef vector adjust_up(vector oldaxis, vector newaxis, vector up, vector save_oldaxis): # adjust up when axis is changed
    cdef double angle
    cdef vector rotaxis
    if abs(newaxis.x) + abs(newaxis.y) + abs(newaxis.z) == 0:
        # If axis has changed to <0,0,0>, must save the old axis to restore later
        if save_oldaxis is None: save_oldaxis = oldaxis
        return save_oldaxis
    if save_oldaxis is not None:
        # Restore saved oldaxis now that newaxis is nonzero
        oldaxis = save_oldaxis
        save_oldaxis = None
    if newaxis.dot(up) != 0: # axis and up not orthogonal
        angle = oldaxis.diff_angle(newaxis)
        if angle > 1e-6: # smaller angles lead to catastrophes
            # If axis is flipped 180 degrees, cross(oldaxis,newaxis) is <0,0,0>:
            if abs(angle-pi) < 1e-6:
                up._x = -up._x
                up._y = -up._y
                up._z = -up._z
            else:
                rotaxis = oldaxis.cross(newaxis)
                up.rotate_in_place(angle=angle, axis=rotaxis) # avoid creating a new vector
    oldaxis._x = newaxis._x # avoid creating a new vector
    oldaxis._y = newaxis._y
    oldaxis._z = newaxis._z
    return save_oldaxis

cpdef vector adjust_axis(vector oldup, vector newup, vector axis, vector save_oldup): # adjust axis when up is changed
    cdef double angle
    cdef vector rotaxis
    if abs(newup.x) + abs(newup.y) + abs(newup.z) == 0:
        # If up will be set to <0,0,0>, must save the old up to restore later
        if save_oldup is None: save_oldup = oldup
        return save_oldup
    if save_oldup is not None:
        # Restore saved oldup now that newup is nonzero
        oldup = save_oldup
        save_oldup = None
    if newup.dot(axis) != 0: # axis and up not orthogonal
        angle = oldup.diff_angle(newup)
        if angle > 1e-6: # smaller angles lead to catastrophes
            # If up is flipped 180 degrees, cross(oldup,newup) is <0,0,0>:
            if abs(angle-pi) < 1e-6:
                axis._x = -axis._x
                axis._y = -axis._y
                axis._z = -axis._z
            else:
                rotaxis = oldup.cross(newup)
                axis.rotate_in_place(angle=angle, axis=rotaxis) # avoid creating a new vector
    oldup._x = newup._x # avoid creating a new vector
    oldup._y = newup._y
    oldup._z = newup._z
    return save_oldup