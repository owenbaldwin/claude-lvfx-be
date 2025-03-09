class User < ApplicationRecord
  has_secure_password
  
  has_many :production_users
  has_many :productions, through: :production_users
  
  validates :email, presence: true, uniqueness: true
  validates :password_digest, presence: true
end