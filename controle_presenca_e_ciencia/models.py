from sqlalchemy import Column, Integer, String, DateTime, Text, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base


class ATA(Base):
    __tablename__ = "atas"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    sharepoint_url = Column(Text, nullable=False)
    meeting_date = Column(String(20), nullable=True)
    created_by_email = Column(String(255), nullable=False)
    created_by_name = Column(String(255), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    is_active = Column(Boolean, default=True)

    assignments = relationship("Assignment", back_populates="ata", lazy="selectin")


class Assignment(Base):
    __tablename__ = "assignments"

    id = Column(Integer, primary_key=True, index=True)
    ata_id = Column(Integer, ForeignKey("atas.id"), nullable=False)
    user_email = Column(String(255), nullable=False)
    user_name = Column(String(255), nullable=True)
    signed_at = Column(DateTime, nullable=True)
    sign_ip = Column(String(50), nullable=True)
    email_sent = Column(Boolean, default=False)
    email_sent_at = Column(DateTime, nullable=True)

    ata = relationship("ATA", back_populates="assignments")
